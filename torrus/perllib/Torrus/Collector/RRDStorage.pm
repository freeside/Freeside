#  Copyright (C) 2002-2007  Stanislav Sinyagin
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

# $Id: RRDStorage.pm,v 1.1 2010-12-27 00:03:58 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::Collector::RRDStorage;

use Torrus::ConfigTree;
use Torrus::Log;

use strict;
use RRDs;

our $useThreads;
our $threadsInUse = 0;
our $thrQueueLimit;
our $thrUpdateQueue;
our $thrErrorsQueue;
# RRDtool is not reentrant. use this semaphore for every call to RRDs::*
our $rrdtoolSemaphore;
our $thrUpdateThread;

our $moveConflictRRD;
our $conflictRRDPath;

# Register the storage type
$Torrus::Collector::storageTypes{'rrd'} = 1;


# List of needed parameters and default values

$Torrus::Collector::params{'rrd-storage'} = {
    'data-dir' => undef,
    'data-file' => undef,
    'rrd-create-rra' => undef,
    'rrd-create-heartbeat' => undef,
    'rrd-create-min'  => 'U',
    'rrd-create-max'  => 'U',
    'rrd-hwpredict'   => {
        'enabled' => {
            'rrd-create-hw-alpha' => 0.1,
            'rrd-create-hw-beta'  => 0.0035,
            'rrd-create-hw-gamma' => 0.1,
            'rrd-create-hw-winlen' => 9,
            'rrd-create-hw-failth' => 6,
            'rrd-create-hw-season' => 288,
            'rrd-create-hw-rralen' => undef },
        'disabled' => undef },
    'rrd-create-dstype' => undef,
    'rrd-ds' => undef
    };


$Torrus::Collector::initThreadsHandlers{'rrd-storage'} =
    \&Torrus::Collector::RRDStorage::initThreads;

sub initThreads
{
    if( $useThreads and not defined( $thrUpdateThread ) )
    {
        Verbose('RRD storage is configured for multithreading. Initializing ' .
                'the background thread');
        require threads;
        require threads::shared;
        require Thread::Queue;
        require Thread::Semaphore;

        $thrUpdateQueue = new Thread::Queue;
        $thrErrorsQueue = new Thread::Queue;
        $rrdtoolSemaphore = new Thread::Semaphore;
        
        $thrUpdateThread = threads->create( \&rrdUpdateThread );
        $thrUpdateThread->detach();
        $threadsInUse = 1;
    }
}



$Torrus::Collector::initTarget{'rrd-storage'} =
    \&Torrus::Collector::RRDStorage::initTarget;

sub initTarget
{
    my $collector = shift;
    my $token = shift;

    my $sref = $collector->storageData( 'rrd' );

    $collector->registerDeleteCallback
        ( $token, \&Torrus::Collector::RRDStorage::deleteTarget );

    my $filename =
        $collector->param($token, 'data-dir') . '/' .
        $collector->param($token, 'data-file');

    $sref->{'byfile'}{$filename}{$token} = 1;
    $sref->{'filename'}{$token} = $filename;
}



$Torrus::Collector::setValue{'rrd'} =
    \&Torrus::Collector::RRDStorage::setValue;


sub setValue
{
    my $collector = shift;
    my $token = shift;
    my $value = shift;
    my $timestamp = shift;
    my $uptime = shift;

    my $sref = $collector->storageData( 'rrd' );

    $sref->{'values'}{$token} = [$value, $timestamp, $uptime];
}


$Torrus::Collector::storeData{'rrd'} =
    \&Torrus::Collector::RRDStorage::storeData;

sub storeData
{
    my $collector = shift;
    my $sref = shift;

    if( $threadsInUse )
    {
        $collector->setStatValue( 'RRDQueue', $thrUpdateQueue->pending() );
    }
    
    if( $threadsInUse and $thrUpdateQueue->pending() > $thrQueueLimit )
    {
        Error('Cannot enqueue RRD files for updating: ' .
              'queue size is above limit');
    }
    else
    {
        while( my ($filename, $tokens) = each %{$sref->{'byfile'}} )
        {
            &Torrus::DB::checkInterrupted();
            
            if( not -e $filename )
            {
                createRRD( $collector, $sref, $filename, $tokens );
            }
            
            if( -e $filename )
            {
                updateRRD( $collector, $sref, $filename, $tokens );
            }
        }
    }

    delete $sref->{'values'};
}


sub semaphoreDown
{    
    if( $threadsInUse )
    {
        $rrdtoolSemaphore->down();
    }
}

sub semaphoreUp
{
    if( $threadsInUse )
    {
        $rrdtoolSemaphore->up();
    }
}


sub createRRD
{
    my $collector = shift;
    my $sref = shift;
    my $filename = shift;
    my $tokens  = shift;

    # We use hashes here, in order to make the superset of RRA
    # definitions, and unique RRD names
    my %DS_hash;
    my %RRA_hash;

    # Holt-Winters parameters
    my $needs_hw = 0;
    my %hwparam;

    my $timestamp = time();

    foreach my $token ( keys %{$tokens} )
    {
        my $ds_string =
            sprintf('DS:%s:%s:%d:%s:%s',
                    $collector->param($token, 'rrd-ds'),
                    $collector->param($token, 'rrd-create-dstype'),
                    $collector->param($token, 'rrd-create-heartbeat'),
                    $collector->param($token, 'rrd-create-min'),
                    $collector->param($token, 'rrd-create-max'));
        $DS_hash{$ds_string} = 1;

        foreach my $rra_string
            ( split(/\s+/, $collector->param($token, 'rrd-create-rra')) )
        {
            $RRA_hash{$rra_string} = 1;
        }

        if( $collector->param($token, 'rrd-hwpredict') eq 'enabled' )
        {
            $needs_hw = 1;

            foreach my $param ( 'alpha', 'beta', 'gamma', 'winlen', 'failth',
                                'season', 'rralen' )
            {
                my $value = $collector->param($token, 'rrd-create-hw-'.$param);

                if( defined( $hwparam{$param} ) and
                    $hwparam{$param} != $value )
                {
                    my $paramname = 'rrd-create-hw-'.$param;
                    Warn("Parameter " . $paramname . " was already defined " .
                         "with differentr value for " . $filename);
                }

                $hwparam{$param} = $value;
            }
        }

        if( ref $sref->{'values'}{$token} )
        {
            my $new_ts = $sref->{'values'}{$token}[1];
            if( $new_ts > 0 and $new_ts < $timestamp )
            {
                $timestamp = $new_ts;
            }
        }
    }

    my @DS = sort keys %DS_hash;
    my @RRA = sort keys %RRA_hash;

    if( $needs_hw )
    {
        ## Define the RRAs for Holt-Winters prediction

        my $hwpredict_rran   = scalar(@RRA) + 1;
        my $seasonal_rran    = $hwpredict_rran + 1;
        my $devseasonal_rran = $hwpredict_rran + 2;
        my $devpredict_rran  = $hwpredict_rran + 3;
        my $failures_rran    = $hwpredict_rran + 4;

        push( @RRA, sprintf('RRA:HWPREDICT:%d:%e:%e:%d:%d',
                            $hwparam{'rralen'},
                            $hwparam{'alpha'},
                            $hwparam{'beta'},
                            $hwparam{'season'},
                            $seasonal_rran));

        push( @RRA, sprintf('RRA:SEASONAL:%d:%e:%d',
                            $hwparam{'season'},
                            $hwparam{'gamma'},
                            $hwpredict_rran));

        push( @RRA, sprintf('RRA:DEVSEASONAL:%d:%e:%d',
                            $hwparam{'season'},
                            $hwparam{'gamma'},
                            $hwpredict_rran));

        push( @RRA, sprintf('RRA:DEVPREDICT:%d:%d',
                            $hwparam{'rralen'},
                            $devseasonal_rran));

        push( @RRA, sprintf('RRA:FAILURES:%d:%d:%d:%d',
                            $hwparam{'rralen'},
                            $hwparam{'failth'},
                            $hwparam{'winlen'},
                            $devseasonal_rran));
    }

    my $step = $collector->period();
    my $start = $timestamp - $step;

    my @OPT = ( sprintf( '--start=%d', $start ),
                sprintf( '--step=%d', $step ) );

    &Torrus::DB::checkInterrupted();
    
    Debug("Creating RRD $filename: " . join(" ", @OPT, @DS, @RRA));

    semaphoreDown();
    
    RRDs::create($filename,
                 @OPT,
                 @DS,
                 @RRA);

    my $err = RRDs::error();

    semaphoreUp();

    Error("ERROR creating $filename: $err") if $err;
    
    delete $sref->{'rrdinfo_ds'}{$filename};
}


sub updateRRD
{
    my $collector = shift;
    my $sref = shift;
    my $filename = shift;
    my $tokens  = shift;

    if( not defined( $sref->{'rrdinfo_ds'}{$filename} ) )
    {
        my $ref = {};
        $sref->{'rrdinfo_ds'}{$filename} = $ref;

        semaphoreDown();
        
        my $rrdinfo = RRDs::info( $filename );

        semaphoreUp();

        foreach my $prop ( keys %$rrdinfo )
        {
            if( $prop =~ /^ds\[(\S+)\]\./o )
            {
                $ref->{$1} = 1;
            }
        }
        
        &Torrus::DB::checkInterrupted();
    }

    # First we compare the sets of datasources in our memory and in RRD file
    my %ds_updating = ();
    my $ds_conflict = 0;

    foreach my $token ( keys %{$tokens} )
    {
        $ds_updating{ $collector->param($token, 'rrd-ds') } = $token;
    }

    # Check if we update all datasources in RRD file
    foreach my $ds ( keys %{$sref->{'rrdinfo_ds'}{$filename}} )
    {
        if( not $ds_updating{$ds} )
        {
            Warn('Datasource exists in RRD file, but it is not updated: ' .
                 $ds . ' in ' . $filename);
            $ds_conflict = 1;
        }
    }

    # Check if all DS that we update are defined in RRD
    foreach my $ds ( keys %ds_updating )
    {
        if( not $sref->{'rrdinfo_ds'}{$filename}{$ds} )
        {
            Error("Datasource being updated does not exist: $ds in $filename");
            delete $ds_updating{$ds};
            $ds_conflict = 1;
        }
    }

    if( $ds_conflict and $moveConflictRRD )
    {
        if( not -f $filename )
        {
            Error($filename . 'is not a regular file');
            return;
        }
        
        my( $sec, $min, $hour, $mday, $mon, $year) = localtime( time() );
        my $destfile = sprintf('%s_%04d%02d%02d%02d%02d',
                               $filename,
                               $year + 1900, $mon+1, $mday, $hour, $min);
        
        my $destdir = $conflictRRDPath;
        if( defined( $destdir ) and -d $destdir )
        {
            my @fpath = split('/', $destfile);
            my $fname = pop( @fpath );
            $destfile = $destdir . '/' . $fname;
        }

        Warn('Moving the conflicted RRD file ' . $filename .
             ' to ' . $destfile);
        rename( $filename, $destfile ) or
            Error("Cannot rename $filename to $destfile: $!");
        
        delete $sref->{'rrdinfo_ds'}{$filename};
        
        createRRD( $collector, $sref, $filename, $tokens );
    }
        
    if( scalar( keys %ds_updating ) == 0 )
    {
        Error("No datasources to update in $filename");
        return;
    }

    &Torrus::DB::checkInterrupted();

    # Build the arguments for RRDs::update.
    my $template;
    my $values;

    # We will use the average timestamp
    my @timestamps;
    my $max_ts = 0;
    my $min_ts = time();

    my $step = $collector->period();

    foreach my $ds ( keys %ds_updating )
    {
        my $token = $ds_updating{$ds};
        if( length($template) > 0 )
        {
            $template .= ':';
        }
        $template .= $ds;

        my $now = time();
        my ( $value, $timestamp, $uptime ) = ( 'U', $now, $now );
        if( ref $sref->{'values'}{$token} )
        {
            ($value, $timestamp, $uptime) = @{$sref->{'values'}{$token}};
        }

        push( @timestamps, $timestamp );
        if( $timestamp > $max_ts )
        {
            $max_ts = $timestamp;
        }
        if( $timestamp < $min_ts )
        {
            $min_ts = $timestamp;
        }

        # The plus sign generated by BigInt is not a problem for rrdtool
        $values .= ':'. $value;
    }

    # Get the average timestamp
    my $sum = 0;
    map {$sum += $_} @timestamps;
    my $avg_ts = $sum / scalar( @timestamps );

    if( ($max_ts - $avg_ts) > $Torrus::Global::RRDTimestampTolerance )
    {
        Error("Maximum timestamp value is beyond the tolerance in $filename");
    }
    if( ($avg_ts - $min_ts) > $Torrus::Global::RRDTimestampTolerance )
    {
        Error("Minimum timestamp value is beyond the tolerance in $filename");
    }

    my @cmd = ( "--template=" . $template,
                sprintf("%d%s", $avg_ts, $values) );

    &Torrus::DB::checkInterrupted();

    if( $threadsInUse )
    {
        # Process errors from RRD update thread
        my $errfilename;
        while( defined( $errfilename = $thrErrorsQueue->dequeue_nb() ) )
        {
            delete $sref->{'rrdinfo_ds'}{$errfilename};
        }

        Debug('Enqueueing update job for ' . $filename);
        
        my $cmdlist = &threads::shared::share([]);
        push( @{$cmdlist}, $filename, @cmd );
        $thrUpdateQueue->enqueue( $cmdlist );
    }
    else
    {
        if( isDebug )
        {
            Debug("Updating $filename: " . join(' ', @cmd));
        }
        RRDs::update( $filename, @cmd );
        my $err = RRDs::error();
        if( $err )
        {
            Error("ERROR updating $filename: $err");
            delete $sref->{'rrdinfo_ds'}{$filename};
        }
    }
}


# A background thread that updates RRD files
sub rrdUpdateThread
{
    &Torrus::DB::setSafeSignalHandlers();
    $| = 1;
    &Torrus::Log::setTID( threads->tid() );
    
    my $cmdlist;
    &threads::shared::share( \$cmdlist );
    
    while(1)
    {
        &Torrus::DB::checkInterrupted();
        
        $cmdlist = $thrUpdateQueue->dequeue();
        
        if( isDebug )
        {
            Debug("Updating RRD: " . join(' ', @{$cmdlist}));
        }

        $rrdtoolSemaphore->down();

        RRDs::update( @{$cmdlist} );
        my $err = RRDs::error();

        $rrdtoolSemaphore->up();

        if( $err )
        {
            Error('ERROR updating' . $cmdlist->[0] . ': ' . $err);
            $thrErrorsQueue->enqueue( $cmdlist->[0] );
        }
    }
}



# Callback executed by Collector

sub deleteTarget
{
    my $collector = shift;
    my $token = shift;

    my $sref = $collector->storageData( 'rrd' );
    my $filename = $sref->{'filename'}{$token};

    delete $sref->{'filename'}{$token};

    delete $sref->{'byfile'}{$filename}{$token};
    if( scalar( keys %{$sref->{'byfile'}{$filename}} ) == 0 )
    {
        delete $sref->{'byfile'}{$filename};
    }

    delete $sref->{'values'}{$token};
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
