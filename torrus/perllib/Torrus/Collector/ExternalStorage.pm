#  Copyright (C) 2005  Stanislav Sinyagin
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

# $Id: ExternalStorage.pm,v 1.1 2010-12-27 00:03:57 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::Collector::ExternalStorage;

use Torrus::ConfigTree;
use Torrus::Log;

use strict;
use Math::BigInt;
use Math::BigFloat;

# Pluggable backend module implements all storage-specific tasks
BEGIN
{
    eval( 'require ' . $Torrus::Collector::ExternalStorage::backend );
    die( $@ ) if $@;    
}

# These variables must be set by the backend module
our $backendInit;
our $backendOpenSession;
our $backendStoreData;
our $backendCloseSession;

# Register the storage type
$Torrus::Collector::storageTypes{'ext'} = 1;


# List of needed parameters and default values

$Torrus::Collector::params{'ext-storage'} = {
    'ext-dstype' => {
        'GAUGE' => undef,
        'COUNTER32' => {
            'ext-counter-max' => undef},
        'COUNTER64' => {
            'ext-counter-max' => undef}},
    'ext-service-id' => undef
    };




$Torrus::Collector::initTarget{'ext-storage'} =
    \&Torrus::Collector::ExternalStorage::initTarget;

sub initTarget
{
    my $collector = shift;
    my $token = shift;

    my $sref = $collector->storageData( 'ext' );

    $collector->registerDeleteCallback
        ( $token, \&Torrus::Collector::ExternalStorage::deleteTarget );

    my $serviceid =
        $collector->param($token, 'ext-service-id');

    if( defined( $sref->{'serviceid'}{$serviceid} ) )
    {
        Error('ext-service-id is not unique: "' . $serviceid .
              '". External storage is not activated for ' .
              $collector->path($token));
        return;
    }

    $sref->{'serviceid'}{$serviceid} = 1;

    my $processor;
    my $dstype = $collector->param($token, 'ext-dstype');
    if( $dstype eq 'GAUGE' )
    {
        $processor = \&Torrus::Collector::ExternalStorage::processGauge;
    }
    else
    {
        if( $dstype eq 'COUNTER32' )
        {
            $processor =
                \&Torrus::Collector::ExternalStorage::processCounter32;
        }
        else
        {
            $processor =
                \&Torrus::Collector::ExternalStorage::processCounter64;
        }
        
        my $max = $collector->param( $token, 'ext-counter-max' );
        if( defined( $max ) )
        {
            $sref->{'max'}{$token} = Math::BigFloat->new($max);
        }
    }

    $sref->{'tokens'}{$token} = $processor;

    &{$backendInit}( $collector, $token );
}



$Torrus::Collector::setValue{'ext'} =
    \&Torrus::Collector::ExternalStorage::setValue;


sub setValue
{
    my $collector = shift;
    my $token = shift;
    my $value = shift;
    my $timestamp = shift;

    my $sref = $collector->storageData( 'ext' );

    my $prevTimestamp = $sref->{'prevTimestamp'}{$token};
    if( not defined( $prevTimestamp ) )
    {
        $prevTimestamp = $timestamp;
    }
        
    my $procvalue =
        &{$sref->{'tokens'}{$token}}( $collector, $token, $value, $timestamp );
    if( defined( $procvalue ) )
    {
        if( ref( $procvalue ) )
        {
            # Convert a BigFloat into a scientific notation string
            $procvalue = $procvalue->bsstr();
        }
        $sref->{'values'}{$token} =
            [$procvalue, $timestamp, $timestamp - $prevTimestamp];
    }
    
    $sref->{'prevTimestamp'}{$token} = $timestamp;
}


sub processGauge
{
    my $collector = shift;
    my $token = shift;
    my $value = shift;
    my $timestamp = shift;

    return $value;
}


sub processCounter32
{
    my $collector = shift;
    my $token = shift;
    my $value = shift;
    my $timestamp = shift;

    return processCounter( 32, $collector, $token, $value, $timestamp );
}

sub processCounter64
{
    my $collector = shift;
    my $token = shift;
    my $value = shift;
    my $timestamp = shift;

    return processCounter( 64, $collector, $token, $value, $timestamp );
}

my $base32 = Math::BigInt->new(2)->bpow(32);
my $base64 = Math::BigInt->new(2)->bpow(64);

sub processCounter
{
    my $base = shift;
    my $collector = shift;
    my $token = shift;
    my $value = shift;
    my $timestamp = shift;

    my $sref = $collector->storageData( 'ext' );

    if( isDebug() )
    {
        Debug('ExternalStorage::processCounter: token=' . $token .
              ' value=' . $value . ' timestamp=' . $timestamp);
    }

    if( $value eq 'U' )
    {
        # the agent rebooted, so we flush the counter
        delete $sref->{'prevCounter'}{$token};
        return undef;
    }
        
    $value = Math::BigInt->new( $value );
    my $ret;
    
    if( exists( $sref->{'prevCounter'}{$token} ) )
    {
        my $prevValue = $sref->{'prevCounter'}{$token};
        my $prevTimestamp = $sref->{'prevTimestamp'}{$token};
        if( isDebug() )
        {
            Debug('ExternalStorage::processCounter: prevValue=' . $prevValue .
                  ' prevTimestamp=' . $prevTimestamp);
        }
        
        if( $prevValue->bcmp( $value ) > 0 ) # previous is bigger
        {
            $ret = Math::BigFloat->new($base==32 ? $base32:$base64);
            $ret->bsub( $prevValue );
            $ret->badd( $value );
        }
        else
        {
            $ret = Math::BigFloat->new( $value );
            $ret->bsub( $prevValue );
        }
        $ret->bdiv( $timestamp - $prevTimestamp );
        if( defined( $sref->{'max'}{$token} ) )
        {
            if( $ret->bcmp( $sref->{'max'}{$token} ) > 0 )
            {
                Debug('Resulting counter rate is above the maximum');
                $ret = undef;
            }
        }
    }

    $sref->{'prevCounter'}{$token} = $value;

    if( defined( $ret ) and isDebug() )
    {
        Debug('ExternalStorage::processCounter: Resulting value=' . $ret);
    }
    return $ret;
}



$Torrus::Collector::storeData{'ext'} =
    \&Torrus::Collector::ExternalStorage::storeData;

# timestamp of last unavailable storage
my $storageUnavailable = 0;

# Last time we tried to reach it
my $storageLastTry = 0;

# how often we retry - configurable in torrus-config.pl
our $unavailableRetry;

# maximum age for backlog in case of unavailable storage.
# We stop recording new data when maxage is reached.
our $backlogMaxAge;

sub storeData
{
    my $collector = shift;
    my $sref = shift;

    &Torrus::DB::checkInterrupted();

    my $nTokens = scalar( keys %{$sref->{'values'}} );

    if( $nTokens == 0 )
    {
        return;
    }
    
    Verbose('Exporting data to external storage for ' .
            $nTokens . ' tokens');
    &{$backendOpenSession}();
    
    while( my($token, $valuetriple) = each( %{$sref->{'values'}} ) )
    {
        &Torrus::DB::checkInterrupted();
        
        my( $value, $timestamp, $interval ) = @{$valuetriple};
        my $serviceid =
            $collector->param($token, 'ext-service-id');
        
        my $toBacklog = 0;
        
        if( $storageUnavailable > 0 and 
            time() < $storageLastTry + $unavailableRetry )
        {
            $toBacklog = 1;
        }
        else
        {
            $storageUnavailable = 0;
            $storageLastTry = time();
            
            if( exists( $sref->{'backlog'} ) )
            {
                # Try to flush the backlog first
                Verbose('Trying to flush the backlog');
                    
                my $ok = 1;
                while( scalar(@{$sref->{'backlog'}}) > 0 and $ok )
                {
                    my $quarter = shift @{$sref->{'backlog'}};
                    if( not &{$backendStoreData}( @{$quarter} ) )
                    {
                        Warn('Unable to flush the backlog, external ' .
                             'storage is unavailable');
                        
                        unshift( @{$sref->{'backlog'}}, $quarter );
                        $ok = 0;
                        $toBacklog = 1;
                    }
                }
                if( $ok )
                {
                    delete( $sref->{'backlog'} );
                    Verbose('Backlog is successfully flushed');
                }                    
            }
            
            if( not $toBacklog )
            {
                if( not &{$backendStoreData}( $timestamp, $serviceid,
                                              $value, $interval ) )
                {
                    Warn('Unable to store data, external storage is ' .
                         'unavailable. Saving data to backlog');
                    
                    $toBacklog = 1;                    
                }
            }
        }
        
        if( $toBacklog )
        {
            if( $storageUnavailable == 0 )
            {
                $storageUnavailable = time();
            }
            
            if( not exists( $sref->{'backlog'} ) )
            {
                $sref->{'backlog'} = [];
                $sref->{'backlogStart'} = time();
            }
            
            if( time() < $sref->{'backlogStart'} + $backlogMaxAge )
            {
                push( @{$sref->{'backlog'}},
                      [ $timestamp, $serviceid, $value, $interval ] );
            }
            else
            {
                Error('Backlog has reached its maximum age, stopped storing ' .
                      'any more data');
            }
        }
    }    
    
    undef $sref->{'values'};
    &{$backendCloseSession}();
}





# Callback executed by Collector

sub deleteTarget
{
    my $collector = shift;
    my $token = shift;

    my $sref = $collector->storageData( 'ext' );

    my $serviceid =
        $collector->param($token, 'ext-service-id');
    delete $sref->{'serviceid'}{$serviceid};

    if( defined( $sref->{'prevCounter'}{$token} ) )
    {
        delete $sref->{'prevCounter'}{$token};
    }
    
    delete $sref->{'tokens'}{$token};
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
