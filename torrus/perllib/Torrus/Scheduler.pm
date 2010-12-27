#  Copyright (C) 2002  Stanislav Sinyagin
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

# $Id: Scheduler.pm,v 1.1 2010-12-27 00:03:39 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


# Task scheduler.
# Task object MUST implement two methods:
# run() -- the running cycle
# whenNext() -- returns the next time it must be run.
# See below the Torrus::Scheduler::PeriodicTask class definition
#
# Options:
#   -Tree        => tree name
#   -ProcessName => process name and commandline options
#   -RunOnce     => 1       -- this prevents from infinite loop.   


package Torrus::Scheduler;

use strict;
use Torrus::SchedulerInfo;
use Torrus::Log;

sub new
{
    my $self = {};
    my $class = shift;
    my %options = @_;
    bless $self, $class;

    %{$self->{'options'}} = %options;
    %{$self->{'data'}} = ();

    if( not defined( $options{'-Tree'} ) or
        not defined( $options{'-ProcessName'} ) )
    {
        die();
    }

    $self->{'stats'} = new Torrus::SchedulerInfo( -Tree => $options{'-Tree'},
                                                  -WriteAccess => 1 );    
    return $self;
}


sub DESTROY
{
    my $self = shift;
    delete $self->{'stats'};
}

sub treeName
{
    my $self = shift;
    return $self->{'options'}{'-Tree'};
}

sub setProcessStatus
{
    my $self = shift;
    my $text = shift;
    $0 = $self->{'options'}{'-ProcessName'} . ' [' . $text . ']';
}

sub addTask
{
    my $self = shift;
    my $task = shift;
    my $when = shift;

    if( not defined $when )
    {
        # If not specified, run immediately
        $when = time() - 1;
    }
    $self->storeTask( $task, $when );
    $self->{'stats'}->clearStats( $task->id() );
}


sub storeTask
{
    my $self = shift;
    my $task = shift;
    my $when = shift;

    if( not defined( $self->{'tasks'}{$when} ) )
    {
        $self->{'tasks'}{$when} = [];
    }
    push( @{$self->{'tasks'}{$when}}, $task );
}
    

sub flushTasks
{
    my $self = shift;

    if( defined( $self->{'tasks'} ) )
    {
        foreach my $when ( keys %{$self->{'tasks'}} )
        {
            foreach my $task ( @{$self->{'tasks'}{$when}} )
            {
                $self->{'stats'}->clearStats( $task->id() );
            }
        }
        undef $self->{'tasks'};
    }
}


sub run
{
    my $self = shift;

    my $stop = 0;

    while( not $stop )
    {
        $self->setProcessStatus('initializing scheduler');
        while( not $self->beforeRun() )
        {
            &Torrus::DB::checkInterrupted();
            
            Error('Scheduler initialization error. Sleeping ' .
                  $Torrus::Scheduler::failedInitSleep . ' seconds');

            &Torrus::DB::setUnsafeSignalHandlers();
            sleep($Torrus::Scheduler::failedInitSleep);
            &Torrus::DB::setSafeSignalHandlers();
        }
        $self->setProcessStatus('');
        my $nextRun = time() + 3600;
        foreach my $when ( keys %{$self->{'tasks'}} )
        {
            # We have 1-second rounding error
            if( $when <= time() + 1 )
            {
                foreach my $task ( @{$self->{'tasks'}{$when}} )
                {
                    &Torrus::DB::checkInterrupted();
                    
                    my $startTime = time();

                    $self->beforeTaskRun( $task, $startTime, $when );
                    $task->beforeRun( $self->{'stats'} );

                    $self->setProcessStatus('running');
                    $task->run();
                    my $whenNext = $task->whenNext();
                    
                    $task->afterRun( $self->{'stats'}, $startTime );
                    $self->afterTaskRun( $task, $startTime );
                    
                    if( $whenNext > 0 )
                    {
                        if( $whenNext == $when )
                        {
                            Error("Incorrect time returned by task");
                        }
                        $self->storeTask( $task, $whenNext );
                        if( $nextRun > $whenNext )
                        {
                            $nextRun = $whenNext;
                        }
                    }
                }
                delete $self->{'tasks'}{$when};
            }
            elsif( $nextRun > $when )
            {
                $nextRun = $when;
            }
        }

        if( $self->{'options'}{'-RunOnce'} or
            ( scalar( keys %{$self->{'tasks'}} ) == 0 and
              not $self->{'options'}{'-RunAlways'} ) )
        {
            $self->setProcessStatus('');
            $stop = 1;
        }
        else
        {
            if( scalar( keys %{$self->{'tasks'}} ) == 0 )
            {
                Info('Tasks list is empty. Will sleep until ' .
                     scalar(localtime($nextRun)));
            }

            $self->setProcessStatus('sleeping');
            &Torrus::DB::setUnsafeSignalHandlers();            
            Debug('We will sleep until ' . scalar(localtime($nextRun)));
            
            if( $Torrus::Scheduler::maxSleepTime > 0 )
            {
                Debug('This is a VmWare-like clock. We devide the sleep ' .
                      'interval into small pieces');
                while( time() < $nextRun )
                {
                    my $sleep = $nextRun - time();
                    if( $sleep > $Torrus::Scheduler::maxSleepTime )
                    {
                        $sleep = $Torrus::Scheduler::maxSleepTime;
                    }
                    Debug('Sleeping ' . $sleep . ' seconds');
                    sleep( $sleep );
                }
            }
            else
            {
                my $sleep = $nextRun - time();
                if( $sleep > 0 )
                {
                    sleep( $sleep );
                }
            }

            &Torrus::DB::setSafeSignalHandlers();
        }
    }
}


# A method to override by ancestors. Executed every time before the
# running cycle. Must return true value when finishes.
sub beforeRun
{
    my $self = shift;
    Debug('Torrus::Scheduler::beforeRun() - doing nothing');
    return 1;
}


sub beforeTaskRun
{
    my $self = shift;
    my $task = shift;
    my $startTime = shift;
    my $plannedStartTime = shift;

    if( not $task->didNotRun() and  $startTime > $plannedStartTime + 1 )
    {
        my $late = $startTime - $plannedStartTime;
        Verbose(sprintf('Task delayed %d seconds', $late));
        $self->{'stats'}->setStatsValues( $task->id(), 'LateStart', $late );
    }
}


sub afterTaskRun
{
    my $self = shift;
    my $task = shift;
    my $startTime = shift;

    my $len = time() - $startTime;
    Verbose(sprintf('%s task finished in %d seconds', $task->name(), $len));
    
    $self->{'stats'}->setStatsValues( $task->id(), 'RunningTime', $len );
}


# User data can be stored here
sub data
{
    my $self = shift;
    return $self->{'data'};
}


# Periodic task base class
# Options:
#   -Period   => seconds    -- cycle period
#   -Offset   => seconds    -- time offset from even period moments
#   -Name     => "string"   -- Symbolic name for log messages
#   -Instance => N          -- instance number

package Torrus::Scheduler::PeriodicTask;

use Torrus::Log;
use strict;

sub new
{
    my $self = {};
    my $class = shift;
    my %options = @_;
    bless $self, $class;

    if( not defined( $options{'-Instance'} ) )
    {
        $options{'-Instance'} = 0;
    }

    %{$self->{'options'}} = %options;

    $self->{'options'}{'-Period'} = 0 unless
        defined( $self->{'options'}{'-Period'} );

    $self->{'options'}{'-Offset'} = 0 unless
        defined( $self->{'options'}{'-Offset'} );
        
    $self->{'options'}{'-Name'} = "PeriodicTask" unless
        defined( $self->{'options'}{'-Name'} );

    $self->{'missedPeriods'} = 0;

    $self->{'options'}{'-Started'} = time();

    # Array of (Name, Value) pairs for any kind of stats    
    $self->{'statValues'} = [];
    
    Debug("New Periodic Task created: period=" .
          $self->{'options'}{'-Period'} .
          " offset=" . $self->{'options'}{'-Offset'});

    return $self;
}


sub whenNext
{
    my $self = shift;

    if( $self->period() > 0 )
    {
        my $now = time();
        my $period = $self->period();
        my $offset = $self->offset();
        my $previous;

        if( defined $self->{'previousSchedule'} )
        {
            if( $now - $self->{'previousSchedule'} <= $period )
            {
                $previous = $self->{'previousSchedule'};
            }
            elsif( not $Torrus::Scheduler::ignoreClockSkew )
            {
                Error('Last run of ' . $self->{'options'}{'-Name'} .
                      ' was more than ' . $period . ' seconds ago');
                $self->{'missedPeriods'} =
                    int( ($now - $self->{'previousSchedule'}) / $period );
            }
        }
        if( not defined( $previous ) )
        {
            $previous = $now - ($now % $period) + $offset;
        }

        my $whenNext = $previous + $period;
        $self->{'previousSchedule'} = $whenNext;

        Debug("Task ". $self->{'options'}{'-Name'}.
              " wants to run next time at " . scalar(localtime($whenNext)));
        return $whenNext;
    }
    else
    {
        return undef;
    }
}


sub beforeRun
{
    my $self = shift;
    my $stats = shift;

    Verbose(sprintf('%s periodic task started. Period: %d:%.2d; ' .
                    'Offset: %d:%.2d',
                    $self->name(),
                    int( $self->period() / 60 ), $self->period() % 60,
                    int( $self->offset() / 60 ), $self->offset() % 60));    
}


sub afterRun
{
    my $self = shift;
    my $stats = shift;
    my $startTime = shift;
    
    my $len = time() - $startTime;
    if( $len > $self->period() )
    {
        Warn(sprintf('%s task execution (%d) longer than period (%d)',
                     $self->name(), $len, $self->period()));
        
        $stats->setStatsValues( $self->id(), 'TooLong', $len );
        $stats->incStatsCounter( $self->id(), 'OverrunPeriods',
                                 int( $len > $self->period() ) );
    }

    if( $self->{'missedPeriods'} > 0 )
    {
        $stats->incStatsCounter( $self->id(), 'MissedPeriods',
                                 $self->{'missedPeriods'} );
        $self->{'missedPeriods'} = 0;
    }

    foreach my $pair( @{$self->{'statValues'}} )
    {
        $stats->setStatsValues( $self->id(), @{$pair} );
    }
    @{$self->{'statValues'}} = [];
}


sub run
{
    my $self = shift;
    Error("Dummy class Torrus::Scheduler::PeriodicTask was run");
}


sub period
{
    my $self = shift;
    return $self->{'options'}->{'-Period'};
}


sub offset
{
    my $self = shift;
    return $self->{'options'}->{'-Offset'};
}


sub didNotRun
{
    my $self = shift;
    return( not defined( $self->{'previousSchedule'} ) );
}


sub name
{
    my $self = shift;
    return $self->{'options'}->{'-Name'};
}

sub instance
{
    my $self = shift;
    return $self->{'options'}->{'-Instance'};
}


sub whenStarted
{
    my $self = shift;
    return $self->{'options'}->{'-Started'};
}


sub id
{
    my $self = shift;
    return join(':', 'P', $self->name(), $self->instance(),
                $self->period(), $self->offset());
}

sub setStatValue
{
    my $self = shift;
    my $name = shift;
    my $value = shift;

    push( @{$self->{'statValues'}}, [$name, $value] );
}

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
