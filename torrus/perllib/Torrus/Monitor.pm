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

# $Id: Monitor.pm,v 1.1 2010-12-27 00:03:37 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::Monitor;
@Torrus::Monitor::ISA = qw(Torrus::Scheduler::PeriodicTask);

use strict;

use Torrus::DB;
use Torrus::ConfigTree;
use Torrus::Scheduler;
use Torrus::DataAccess;
use Torrus::TimeStamp;
use Torrus::Log;


sub new
{
    my $proto = shift;
    my %options = @_;

    if( not $options{'-Name'} )
    {
        $options{'-Name'} = "Monitor";
    }

    my $class = ref($proto) || $proto;
    my $self  = $class->SUPER::new( %options );
    bless $self, $class;


    $self->{'tree_name'} = $options{'-TreeName'};
    $self->{'sched_data'} = $options{'-SchedData'};
    $self->{'delay'} = $options{'-Delay'} * 60;
    
    return $self;
}


sub addTarget
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;

    if( not defined( $self->{'targets'} ) )
    {
        $self->{'targets'} = [];
    }
    push( @{$self->{'targets'}}, $token );
}




sub run
{
    my $self = shift;
    
    my $config_tree =
        new Torrus::ConfigTree( -TreeName => $self->{'tree_name'},
                                -Wait => 1 );
    if( not defined( $config_tree ) )
    {
        return;
    }

    my $da = new Torrus::DataAccess;
    
    $self->{'db_alarms'} = new Torrus::DB('monitor_alarms',
                                          -Subdir => $self->{'tree_name'},
                                          -WriteAccess => 1);

    foreach my $token ( @{$self->{'targets'}} )
    {
        &Torrus::DB::checkInterrupted();
        
        my $mlist = $self->{'sched_data'}{'mlist'}{$token};
        
        foreach my $mname ( @{$mlist} )
        {
            my $obj = { 'token' => $token, 'mname' => $mname };

            $obj->{'da'} = $da;
            
            my $mtype = $config_tree->getParam($mname, 'monitor-type');
            $obj->{'mtype'} = $mtype;
            
            my $method = 'check_' . $mtype;
            my( $alarm, $timestamp ) = $self->$method( $config_tree, $obj );
            $obj->{'alarm'} = $alarm;
            $obj->{'timestamp'} = $timestamp;
            
            Debug("Monitor $mname returned ($alarm, $timestamp) ".
                  "for token $token");
            
            $self->setAlarm( $config_tree, $obj );
            undef $obj;
        }
    }

    $self->cleanupExpired();
    
    undef $self->{'db_alarms'};
}


sub check_failures
{
    my $self = shift;
    my $config_tree = shift;
    my $obj = shift;

    my $token = $obj->{'token'};
    my $file = $config_tree->getNodeParam( $token, 'data-file' );
    my $dir = $config_tree->getNodeParam( $token, 'data-dir' );
    my $ds = $config_tree->getNodeParam( $token, 'rrd-ds' );

    my ($value, $timestamp) = $obj->{'da'}->read_RRD_DS( $dir.'/'.$file,
                                                         'FAILURES', $ds );
    return( $value > 0 ? 1:0, $timestamp );

}


sub check_expression
{
    my $self = shift;
    my $config_tree = shift;
    my $obj = shift;

    my $token = $obj->{'token'};
    my $mname = $obj->{'mname'};

    my ($value, $timestamp) = $obj->{'da'}->read( $config_tree, $token );
    $value = 'UNKN' unless defined($value);
    
    my $expr = $value . ',' . $config_tree->getParam($mname,'rpn-expr');
    $expr = $self->substitute_vars( $config_tree, $obj, $expr );

    my $display_expr = $config_tree->getParam($mname,'display-rpn-expr');
    if( defined( $display_expr ) )
    {
        $display_expr =
            $self->substitute_vars( $config_tree, $obj,
                                    $value . ',' . $display_expr );
        my ($dv, $dt) = $obj->{'da'}->read_RPN( $config_tree, $token,
                                                $display_expr, $timestamp );
        $obj->{'display_value'} = $dv;
    }
    else
    {
        $obj->{'display_value'} = $value;
    }
    
    return $obj->{'da'}->read_RPN( $config_tree, $token, $expr, $timestamp );
}


sub substitute_vars
{
    my $self = shift;
    my $config_tree = shift;
    my $obj = shift;
    my $expr = shift;
    
    my $token = $obj->{'token'};
    my $mname = $obj->{'mname'};

    if( index( $expr, '#' ) >= 0 )
    {
        my $vars;
        if( exists( $self->{'varscache'}{$token} ) )
        {
            $vars = $self->{'varscache'}{$token};
        }
        else
        {
            my $varstring =
                $config_tree->getNodeParam( $token, 'monitor-vars' );
            foreach my $pair ( split( '\s*;\s*', $varstring ) )
            {
                my( $var, $value ) = split( '\s*\=\s*', $pair );
                $vars->{$var} = $value;
            }
            $self->{'varscache'}{$token} = $vars;
        }

        my $ok = 1;
        while( index( $expr, '#' ) >= 0 and $ok )
        {
            if( not $expr =~ /\#(\w+)/ )
            {
                Error("Error in monitor expression: $expr for monitor $mname");
                $ok = 0;
            }
            else
            {
                my $var = $1;
                my $val = $vars->{$var};
                if( not defined $val )
                {
                    Error("Unknown variable $var in monitor $mname");
                    $ok = 0;
                }
                else
                {
                    $expr =~ s/\#$var/$val$1/g;
                }
            }
        }

    }

    return $expr;
}
    


sub setAlarm
{
    my $self = shift;
    my $config_tree = shift;
    my $obj = shift;

    my $token = $obj->{'token'};
    my $mname = $obj->{'mname'};
    my $alarm = $obj->{'alarm'};
    my $timestamp = $obj->{'timestamp'};

    my $key = $mname . ':' . $config_tree->path($token);
    
    my $prev_values = $self->{'db_alarms'}->get( $key );
    my ($t_set, $t_expires, $prev_status, $t_last_change);
    if( defined($prev_values) )
    {
        Debug("Previous state found, Alarm: $alarm, ".
              "Token: $token, Monitor: $mname");
        ($t_set, $t_expires, $prev_status, $t_last_change) =
            split(':', $prev_values);
    }

    my $event;

    $t_last_change = time();
    
    if( $alarm )
    {
        if( not $prev_status )
        {
            $t_set = $timestamp;
            $event = 'set';
        }
        else
        {
            $event = 'repeat';
        }
    }
    else
    {
        if( $prev_status )
        {
            $t_expires = $t_last_change +
                $config_tree->getParam($mname, 'expires');
            $event = 'clear';
        }
        else
        {
            if( defined($t_expires) and time() > $t_expires )
            {
                $self->{'db_alarms'}->del( $key );
                $event = 'forget';
            }
        }
    }

    if( $event )
    {
        Debug("Event: $event, Monitor: $mname, Token: $token");
        $obj->{'event'} = $event;
        
        my $action_token = $token;
        
        my $action_target =
            $config_tree->getNodeParam($token, 'monitor-action-target');
        if( defined( $action_target ) )
        {
            Debug('Action target redirected to ' . $action_target);
            $action_token = $config_tree->getRelative($token, $action_target);
            Debug('Redirected to token ' . $action_token);
        }
        $obj->{'action_token'} = $action_token;

        foreach my $aname (split(',',
                                 $config_tree->getParam($mname, 'action')))
        {
            &Torrus::DB::checkInterrupted();
            
            Debug("Running action: $aname");
            my $method = 'run_event_' .
                $config_tree->getParam($aname, 'action-type');
            $self->$method( $config_tree, $aname, $obj );
        }

        if( $event ne 'forget' )
        {
            $self->{'db_alarms'}->put( $key,
                                       join(':', ($t_set,
                                                  $t_expires,
                                                  ($alarm ? 1:0),
                                                  $t_last_change)) );
        }
    }
}


# If an alarm is no longer in ConfigTree, it is not cleaned by setAlarm.
# We clean them up explicitly after they expire

sub cleanupExpired
{
    my $self = shift;

    &Torrus::DB::checkInterrupted();
    
    my $cursor = $self->{'db_alarms'}->cursor(-Write => 1);
    while( my ($key, $timers) = $self->{'db_alarms'}->next($cursor) )
    {
        my ($t_set, $t_expires, $prev_status, $t_last_change) =
            split(':', $timers);
        
        if( $t_last_change and
            time() > ( $t_last_change + $Torrus::Monitor::alarmTimeout ) and
            ( (not $t_expires) or (time() > $t_expires) ) )
        {            
            my ($mname, $path) = split(':', $key);
            
            Info('Cleaned up an orphaned alarm: monitor=' . $mname .
                 ', path=' . $path);
            $self->{'db_alarms'}->c_del( $cursor );            
        }
    }
    undef $cursor;
    
    &Torrus::DB::checkInterrupted();
}
    


    

sub run_event_tset
{
    my $self = shift;
    my $config_tree = shift;
    my $aname = shift;
    my $obj = shift;

    my $token = $obj->{'action_token'};
    my $event = $obj->{'event'};
    
    if( $event eq 'set' or $event eq 'forget' )
    {
        my $tset = 'S'.$config_tree->getParam($aname, 'tset-name');

        if( $event eq 'set' )
        {
            $config_tree->tsetAddMember($tset, $token, 'monitor');
        }
        else
        {
            $config_tree->tsetDelMember($tset, $token);
        }
    }
}


sub run_event_exec
{
    my $self = shift;
    my $config_tree = shift;
    my $aname = shift;
    my $obj = shift;

    my $token = $obj->{'action_token'};
    my $event = $obj->{'event'};
    my $mname = $obj->{'mname'};
    my $timestamp = $obj->{'timestamp'};

    my $launch_when = $config_tree->getParam($aname, 'launch-when');
    if( not defined $launch_when )
    {
        $launch_when = 'set';
    }

    if( grep {$event eq $_} split(',', $launch_when) )
    {
        my $cmd = $config_tree->getParam($aname, 'command');
        $cmd =~ s/\&gt\;/\>/;
        $cmd =~ s/\&lt\;/\</;

        $ENV{'TORRUS_BIN'}       = $Torrus::Global::pkgbindir;
        $ENV{'TORRUS_UPTIME'}    = time() - $self->whenStarted();

        $ENV{'TORRUS_TREE'}      = $config_tree->treeName();
        $ENV{'TORRUS_TOKEN'}     = $token;
        $ENV{'TORRUS_NODEPATH'}  = $config_tree->path( $token );

        my $nick =
            $config_tree->getNodeParam( $token, 'descriptive-nickname' );
        if( not defined( $nick ) )
        {
            $nick = $ENV{'TORRUS_NODEPATH'};
        }
        $ENV{'TORRUS_NICKNAME'} = $nick;
        
        $ENV{'TORRUS_NCOMMENT'}  =
            $config_tree->getNodeParam( $token, 'comment', 1 );
        $ENV{'TORRUS_NPCOMMENT'} =
            $config_tree->getNodeParam( $config_tree->getParent( $token ),
                                        'comment', 1 );
        $ENV{'TORRUS_EVENT'}     = $event;
        $ENV{'TORRUS_MONITOR'}   = $mname;
        $ENV{'TORRUS_MCOMMENT'}  = $config_tree->getParam($mname, 'comment');
        $ENV{'TORRUS_TSTAMP'}    = $timestamp;

        if( defined( $obj->{'display_value'} ) )
        {
            $ENV{'TORRUS_VALUE'} = $obj->{'display_value'};

            my $format = $config_tree->getParam($mname, 'display-format');
            if( not defined( $format ) )
            {
                $format = '%.2f';
            }

            $ENV{'TORRUS_DISPLAY_VALUE'} =
                sprintf( $format, $obj->{'display_value'} );
        }

        my $severity = $config_tree->getParam($mname, 'severity');
        if( defined( $severity ) )
        {
            $ENV{'TORRUS_SEVERITY'} = $severity;
        }
        
        my $setenv_params =
            $config_tree->getParam($aname, 'setenv-params');

        if( defined( $setenv_params ) )
        {
            foreach my $param ( split( ',', $setenv_params ) )
            {
                # We retrieve the param from the monitored token, not
                # from action-token
                my $value = $config_tree->getNodeParam( $obj->{'token'},
                                                        $param );
                if( not defined $value )
                {
                    Warn('Parameter ' . $param . ' referenced in action '.
                         $aname . ', but not defined for ' .
                         $config_tree->path($obj->{'token'}));
                    $value = '';
                }
                $param =~ s/\W/_/g;
                my $envName = 'TORRUS_P_'.$param;
                Debug("Setting environment $envName to $value");
                $ENV{$envName} = $value;
            }
        }

        my $setenv_dataexpr =
            $config_tree->getParam($aname, 'setenv-dataexpr');

        if( defined( $setenv_dataexpr ) )
        {
            # <param name="setenv_dataexpr" value="ENV1=expr1, ENV2=expr2"/>
            # Integrity checks are done at compilation time.
            foreach my $pair ( split( ',', $setenv_dataexpr ) )
            {
                my ($env, $param) = split( '=', $pair );
                my $expr = $config_tree->getParam($aname, $param);
                my ($value, $timestamp) =
                    $obj->{'da'}->read_RPN( $config_tree, $token, $expr );
                my $envName = 'TORRUS_'.$env;
                Debug("Setting environment $envName to $value");
                $ENV{$envName} = $value;
            }
        }

        Debug("Going to run command: $cmd");
        my $status = system($cmd);
        if( $status != 0 )
        {
            Error("$cmd executed with error: $!");
        }

        # Clean up the environment
        foreach my $envName ( keys %ENV )
        {
            if( $envName =~ /^TORRUS_/ )
            {
                delete $ENV{$envName};
            }
        }
    }
}



#######  Monitor scheduler  ########

package Torrus::MonitorScheduler;
@Torrus::MonitorScheduler::ISA = qw(Torrus::Scheduler);

use Torrus::ConfigTree;
use Torrus::Log;
use Torrus::Scheduler;
use Torrus::TimeStamp;

sub beforeRun
{
    my $self = shift;

    my $tree = $self->treeName();
    my $config_tree = new Torrus::ConfigTree(-TreeName => $tree, -Wait => 1);
    if( not defined( $config_tree ) )
    {
        return undef;
    }

    my $data = $self->data();

    # Prepare the list of tokens, sorted by period and offset,
    # from config tree or from cache.

    my $need_new_tasks = 0;

    Torrus::TimeStamp::init();
    my $known_ts = Torrus::TimeStamp::get($tree . ':monitor_cache');
    my $actual_ts = $config_tree->getTimestamp();
    if( $actual_ts >= $known_ts )
    {
        if( $self->{'delay'} > 0 )
        {
            Info(sprintf('Delaying for %d seconds', $self->{'delay'}));
            sleep( $self->{'delay'} );
        }

        Info("Rebuilding monitor cache");
        Debug("Config TS: $actual_ts, Monitor TS: $known_ts");

        undef $data->{'targets'};
        $need_new_tasks = 1;

        $data->{'db_tokens'} = new Torrus::DB( 'monitor_tokens',
                                               -Subdir => $tree,
                                               -WriteAccess => 1,
                                               -Truncate    => 1 );
        $self->cacheMonitors( $config_tree, $config_tree->token('/') );
        # explicitly close, since we don't need it often, and sometimes
        # open it in read-only mode
        $data->{'db_tokens'}->closeNow();
        undef $data->{'db_tokens'};

        # Set the timestamp
        &Torrus::TimeStamp::setNow($tree . ':monitor_cache');
    }
    Torrus::TimeStamp::release();

    &Torrus::DB::checkInterrupted();

    if( not $need_new_tasks and not defined $data->{'targets'} )
    {
        $need_new_tasks = 1;

        $data->{'db_tokens'} = new Torrus::DB('monitor_tokens',
                                              -Subdir => $tree);
        my $cursor = $data->{'db_tokens'}->cursor();
        while( my ($token, $schedule) = $data->{'db_tokens'}->next($cursor) )
        {
            my ($period, $offset, $mlist) = split(':', $schedule);
            if( not exists( $data->{'targets'}{$period}{$offset} ) )
            {
                $data->{'targets'}{$period}{$offset} = [];
            }
            push( @{$data->{'targets'}{$period}{$offset}}, $token );
            $data->{'mlist'}{$token} = [];
            push( @{$data->{'mlist'}{$token}}, split(',', $mlist) );
        }
        undef $cursor;
        $data->{'db_tokens'}->closeNow();
        undef $data->{'db_tokens'};
    }

    &Torrus::DB::checkInterrupted();

    # Now fill in Scheduler's task list, if needed

    if( $need_new_tasks )
    {
        Verbose("Initializing tasks");
        my $init_start = time();
        $self->flushTasks();

        foreach my $period ( keys %{$data->{'targets'}} )
        {
            foreach my $offset ( keys %{$data->{'targets'}{$period}} )
            {
                my $monitor = new Torrus::Monitor( -Period => $period,
                                                   -Offset => $offset,
                                                   -TreeName => $tree,
                                                   -SchedData => $data );

                foreach my $token ( @{$data->{'targets'}{$period}{$offset}} )
                {
                    &Torrus::DB::checkInterrupted();
                    
                    $monitor->addTarget( $config_tree, $token );
                }

                $self->addTask( $monitor );
            }
        }
        Verbose(sprintf("Tasks initialization finished in %d seconds",
                        time() - $init_start));
    }

    Verbose("Monitor initialized");

    return 1;
}


sub cacheMonitors
{
    my $self = shift;
    my $config_tree = shift;
    my $ptoken = shift;

    my $data = $self->data();

    foreach my $ctoken ( $config_tree->getChildren( $ptoken ) )
    {
        &Torrus::DB::checkInterrupted();

        if( $config_tree->isSubtree( $ctoken ) )
        {
            $self->cacheMonitors( $config_tree, $ctoken );
        }
        elsif( $config_tree->isLeaf( $ctoken ) and
               ( $config_tree->getNodeParam($ctoken, 'ds-type') ne
                 'rrd-multigraph') )
        {
            my $mlist = $config_tree->getNodeParam( $ctoken, 'monitor' );
            if( defined $mlist )
            {
                my $period = sprintf('%d',
                                     $config_tree->getNodeParam
                                     ( $ctoken, 'monitor-period' ) );
                my $offset = sprintf('%d',
                                     $config_tree->getNodeParam
                                     ( $ctoken, 'monitor-timeoffset' ) );
                
                $data->{'db_tokens'}->put( $ctoken,
                                           $period.':'.$offset.':'.$mlist );
                
                push( @{$data->{'targets'}{$period}{$offset}}, $ctoken );
                $data->{'mlist'}{$ctoken} = [];
                push( @{$data->{'mlist'}{$ctoken}}, split(',', $mlist) );
            }
        }
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
