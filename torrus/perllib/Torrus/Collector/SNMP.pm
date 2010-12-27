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

# $Id: SNMP.pm,v 1.1 2010-12-27 00:03:58 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::Collector::SNMP;

use Torrus::Collector::SNMP_Params;
use Torrus::ConfigTree;
use Torrus::Log;
use Torrus::SNMP_Failures;

use strict;
use Net::hostent;
use Socket;
use Net::SNMP qw(:snmp);
use Math::BigInt;


# Register the collector type
$Torrus::Collector::collectorTypes{'snmp'} = 1;


# List of needed parameters and default values

$Torrus::Collector::params{'snmp'} = {
    'snmp-ipversion'    => undef,
    'snmp-transport'    => undef,
    'snmp-version'      => undef,
    'snmp-port'         => undef,
    'snmp-community'    => undef,
    'snmp-username'     => undef,
    'snmp-authkey'      => undef,
    'snmp-authpassword' => undef,
    'snmp-authprotocol' => 'md5',
    'snmp-privkey'      => undef,
    'snmp-privpassword' => undef,
    'snmp-privprotocol' => 'des',
    'snmp-timeout'      => undef,
    'snmp-retries'      => undef,
    'domain-name'       => undef,
    'snmp-host'         => undef,
    'snmp-localaddr'    => undef,
    'snmp-localport'    => undef,
    'snmp-object'       => undef,
    'snmp-oids-per-pdu' => undef,
    'snmp-object-type'  => 'OTHER',
    'snmp-check-sysuptime' => 'yes',
    'snmp-max-msg-size' => undef,
    'snmp-ignore-mib-errors' => undef,
    };

my $sysUpTime = '1.3.6.1.2.1.1.3.0';

# Hosts that are running SNMPv1. We do not reresh maps on them, as
# they are too slow
my %snmpV1Hosts;

# SNMP tables lookup maps
my %maps;

# Old lookup maps, used temporarily during refresh cycle
my %oldMaps;

# How frequent we refresh the SNMP mapping
our $mapsRefreshPeriod;

# Random factor in refresh period
our $mapsRefreshRandom;

# Time period after configuration re-compile when we refresh existing mappings
our $mapsUpdateInterval;

# how often we check for expired maps
our $mapsExpireCheckPeriod;

# expiration time for each map
my %mapsExpire;

# Lookups scheduled for execution
my %mapLookupScheduled;

# SNMP session objects for map lookups
my @mappingSessions;


# Timestamps of hosts last found unreachable
my %hostUnreachableSeen;

# Last time we tried to reach an unreachable host
my %hostUnreachableRetry;

# Hosts that were deleted because of unreachability for too long
my %unreachableHostDeleted;


our $db_failures;

# Flush stats after a restart or recompile
$Torrus::Collector::initCollectorGlobals{'snmp'} =
    \&Torrus::Collector::SNMP::initCollectorGlobals;

sub initCollectorGlobals
{
    my $tree = shift;
    my $instance = shift;
    
    if( not defined( $db_failures ) )
    {
        $db_failures =
            new Torrus::SNMP_Failures( -Tree => $tree,
                                       -Instance => $instance,
                                       -WriteAccess => 1 );
    }

    if( defined( $db_failures ) )
    {
        $db_failures->init();
    }

    # re-init counters and collect garbage
    %oldMaps = ();
    %hostUnreachableSeen = ();
    %hostUnreachableRetry = ();
    %unreachableHostDeleted = ();
    
    # Configuration re-compile was probably caused by new object instances
    # appearing on the monitored devices. Here we force the maps to refresh
    # soon enough in order to catch up with the changes

    my $now = time();    
    foreach my $maphash ( keys %mapsExpire )
    {
        $mapsExpire{$maphash} = int( $now + rand( $mapsUpdateInterval ) );
    }    
}


# This is first executed per target

$Torrus::Collector::initTarget{'snmp'} = \&Torrus::Collector::SNMP::initTarget;



sub initTarget
{
    my $collector = shift;
    my $token = shift;

    my $tref = $collector->tokenData( $token );
    my $cref = $collector->collectorData( 'snmp' );

    $collector->registerDeleteCallback
        ( $token, \&Torrus::Collector::SNMP::deleteTarget );

    my $hostname = getHostname( $collector, $token );
    if( not defined( $hostname ) )
    {
        return 0;
    }

    $tref->{'hostname'} = $hostname;
    
    return Torrus::Collector::SNMP::initTargetAttributes( $collector, $token );
}


sub initTargetAttributes
{
    my $collector = shift;
    my $token = shift;

    &Torrus::DB::checkInterrupted();

    my $tref = $collector->tokenData( $token );
    my $cref = $collector->collectorData( 'snmp' );

    my $hostname = $tref->{'hostname'};
    my $port = $collector->param($token, 'snmp-port');
    my $version = $collector->param($token, 'snmp-version');

    my $community;
    if( $version eq '1' or $version eq '2c' )
    {
        $community = $collector->param($token, 'snmp-community');
    }
    else
    {
        # We use community string to identify the agent.
        # For SNMPv3, it's the user name
        $community = $collector->param($token, 'snmp-username');
    }

    my $hosthash = join('|', $hostname, $port, $community);
    $tref->{'hosthash'} = $hosthash;

    if( $version eq '1' )
    {
        $snmpV1Hosts{$hosthash} = 1;
    }
    
    # If the object is defined as a map, retrieve the whole map
    # and cache it.

    if( isHostDead( $collector, $hosthash ) )
    {
        return 0;
    }
        
    if( not checkUnreachableRetry( $collector, $hosthash ) )
    {
        $cref->{'needsRemapping'}{$token} = 1;
        return 1;
    }
    
    my $oid = $collector->param($token, 'snmp-object');
    $oid = expandOidMappings( $collector, $token, $hosthash, $oid );

    if( not $oid )
    {
        if( $unreachableHostDeleted{$hosthash} )
        {
            # we tried our best, but the target is dead
            return 0;
        }
        else
        {
            # we return OK status, to let the storage initiate
            $cref->{'needsRemapping'}{$token} = 1;
            return 1;
        }
    }
    elsif( $oid eq 'notfound' )
    {
        return 0;
    }

    # Collector should be able to find the target
    # by host, port, community, and oid.
    # There can be several targets with the same host|port|community+oid set.

    $cref->{'targets'}{$hosthash}{$oid}{$token} = 1;
    $cref->{'activehosts'}{$hosthash} = 1;

    $tref->{'oid'} = $oid;

    $cref->{'oids_per_pdu'}{$hosthash} =
        $collector->param($token, 'snmp-oids-per-pdu');

    if( $collector->param($token, 'snmp-object-type') eq 'COUNTER64' )
    {
        $cref->{'64bit_oid'}{$oid} = 1;
    }

    if( $collector->param($token, 'snmp-check-sysuptime') eq 'no' )
    {
        $cref->{'nosysuptime'}{$hosthash} = 1;
    }

    if( $collector->param($token, 'snmp-ignore-mib-errors') eq 'yes' )
    {
        $cref->{'ignoremiberrors'}{$hosthash}{$oid} = 1;
    }
    
    return 1;
}


sub getHostname
{
    my $collector = shift;
    my $token = shift;

    my $cref = $collector->collectorData( 'snmp' );

    my $hostname = $collector->param($token, 'snmp-host');
    my $domain = $collector->param($token, 'domain-name');
    
    if( length( $domain ) > 0 and
        index($hostname, '.') < 0 and
        index($hostname, ':') < 0 )
    {
        $hostname .= '.' . $domain;
    }
    
    return $hostname;
}


sub snmpSessionArgs
{
    my $collector = shift;
    my $token = shift;
    my $hosthash = shift;

    my $cref = $collector->collectorData( 'snmp' );
    if( defined( $cref->{'snmpargs'}{$hosthash} ) )
    {
        return $cref->{'snmpargs'}{$hosthash};
    }

    my $transport = $collector->param($token, 'snmp-transport') . '/ipv' .
        $collector->param($token, 'snmp-ipversion');
    
    my ($hostname, $port, $community) = split(/\|/o, $hosthash);

    my $version = $collector->param($token, 'snmp-version');
    my $ret = [ -domain       => $transport,
                -hostname     => $hostname,
                -port         => $port,
                -timeout      => $collector->param($token, 'snmp-timeout'),
                -retries      => $collector->param($token, 'snmp-retries'),
                -version      => $version ];
    
    foreach my $arg ( qw(-localaddr -localport) )
    {
        if( defined( $collector->param($token, 'snmp' . $arg) ) )
        {
            push( @{$ret}, $arg, $collector->param($token, 'snmp' . $arg) );
        }
    }
            
    if( $version eq '1' or $version eq '2c' )
    {
        push( @{$ret}, '-community', $community );
    }
    else
    {
        push( @{$ret}, -username, $community);

        foreach my $arg ( qw(-authkey -authpassword -authprotocol
                             -privkey -privpassword -privprotocol) )
        {
            if( defined( $collector->param($token, 'snmp' . $arg) ) )
            {
                push( @{$ret},
                      $arg, $collector->param($token, 'snmp' . $arg) );
            }
        }
    }

    $cref->{'snmpargs'}{$hosthash} = $ret;
    return $ret;
}
              


sub openBlockingSession
{
    my $collector = shift;
    my $token = shift;
    my $hosthash = shift;

    my $args = snmpSessionArgs( $collector, $token, $hosthash );
    my ($session, $error) =
        Net::SNMP->session( @{$args},
                            -nonblocking  => 0,
                            -translate    => ['-all', 0, '-octetstring', 1] );
    if( not defined($session) )
    {
        Error('Cannot create SNMP session for ' . $hosthash . ': ' . $error);
    }
    else
    {
        my $maxmsgsize = $collector->param($token, 'snmp-max-msg-size');
        if( defined( $maxmsgsize ) and $maxmsgsize > 0 )
        {
            $session->max_msg_size( $maxmsgsize );
        }
    }
    
    return $session;
}

sub openNonblockingSession
{
    my $collector = shift;
    my $token = shift;
    my $hosthash = shift;

    my $args = snmpSessionArgs( $collector, $token, $hosthash );
    
    my ($session, $error) =
        Net::SNMP->session( @{$args},
                            -nonblocking  => 0x1,
                            -translate    => ['-timeticks' => 0] );
    if( not defined($session) )
    {
        Error('Cannot create SNMP session for ' . $hosthash . ': ' . $error);
        return undef;
    }
    
    if( $collector->param($token, 'snmp-transport') eq 'udp' )
    {
        # We set SO_RCVBUF only once, because Net::SNMP shares
        # one UDP socket for all sessions.
        
        my $sock_name = $session->transport()->sock_name();
        my $refcount = $Net::SNMP::Transport::SOCKETS->{
            $sock_name}->[&Net::SNMP::Transport::_SHARED_REFC()];
                                                                      
        if( $refcount == 1 )
        {
            my $buflen = int($Torrus::Collector::SNMP::RxBuffer);
            my $socket = $session->transport()->socket();
            my $ok = $socket->sockopt( SO_RCVBUF, $buflen );
            if( not $ok )
            {
                Error('Could not set SO_RCVBUF to ' .
                      $buflen . ': ' . $!);
            }
            else
            {
                Debug('Set SO_RCVBUF to ' . $buflen);
            }
        }
    }

    my $maxmsgsize = $collector->param($token, 'snmp-max-msg-size');
    if( defined( $maxmsgsize ) and $maxmsgsize > 0 )
    {
        $session->max_msg_size( $maxmsgsize );
        
    }
    
    return $session;
}


sub expandOidMappings
{
    my $collector = shift;
    my $token = shift;
    my $hosthash = shift;
    my $oid_in = shift;
        
    my $cref = $collector->collectorData( 'snmp' );

    my $oid = $oid_in;

    # Process Map statements

    while( index( $oid, 'M(' ) >= 0 )
    {
        if( not $oid =~ /^(.*)M\(\s*([0-9\.]+)\s*,\s*([^\)]+)\)(.*)$/o )
        {
            Error("Error in OID mapping syntax: $oid");
            return undef;
        }

        my $head = $1;
        my $map = $2;
        my $key = $3;
        my $tail = $4;

        # Remove trailing space from key
        $key =~ s/\s+$//o;

        my $value =
            lookupMap( $collector, $token, $hosthash, $map, $key );

        if( defined( $value ) )
        {
            if( $value eq 'notfound' )
            {
                return 'notfound';
            }
            else
            {
                $oid = $head . $value . $tail;
            }
        }
        else
        {
            return undef;
        }
    }

    # process value lookups

    while( index( $oid, 'V(' ) >= 0 )
    {
        if( not $oid =~ /^(.*)V\(\s*([0-9\.]+)\s*\)(.*)$/o )
        {
            Error("Error in OID value lookup syntax: $oid");
            return undef;
        }

        my $head = $1;
        my $key = $2;
        my $tail = $4;

        my $value;

        if( not defined( $cref->{'value-lookups'}
                         {$hosthash}{$key} ) )
        {
            # Retrieve the OID value from host

            my $session = openBlockingSession( $collector, $token, $hosthash );
            if( not defined($session) )
            {
                return undef;
            }

            my $result = $session->get_request( -varbindlist => [$key] );
            $session->close();
            if( defined $result and defined($result->{$key}) )
            {
                $value = $result->{$key};
                $cref->{'value-lookups'}{$hosthash}{$key} = $value;
            }
            else
            {
                Error("Error retrieving $key from $hosthash: " .
                      $session->error());
                probablyDead( $collector, $hosthash );
                return undef;
            }
        }
        else
        {
            $value =
                $cref->{'value-lookups'}{$hosthash}{$key};
        }
        if( defined( $value ) )
        {
            $oid = $head . $value . $tail;
        }
        else
        {
            return 'notfound';
        }
    }

    # Debug('OID expanded: ' . $oid_in . ' -> ' . $oid');
    return $oid;
}

# Look up table index in a map by value

sub lookupMap
{
    my $collector = shift;
    my $token = shift;
    my $hosthash = shift;
    my $map = shift;
    my $key = shift;

    my $cref = $collector->collectorData( 'snmp' );
    my $maphash = join('#', $hosthash, $map);
    
    if( not defined( $maps{$hosthash}{$map} ) )
    {
        my $ret;

        if( defined( $oldMaps{$hosthash}{$map} ) and
            defined( $key ) )
        {
            $ret = $oldMaps{$hosthash}{$map}{$key};
        }
        
        if( $mapLookupScheduled{$maphash} )
        {
            return $ret;
        }

        if( scalar(@mappingSessions) >=
            $Torrus::Collector::SNMP::maxSessionsPerDispatcher )
        {
            snmp_dispatcher();
            @mappingSessions = ();
            %mapLookupScheduled = ();
        }

        # Retrieve map from host
        Debug('Retrieving map ' . $map . ' from ' . $hosthash);

        my $session = openNonblockingSession( $collector, $token, $hosthash );
        if( not defined($session) )
        {
            return $ret;
        }
        else
        {
            push( @mappingSessions, $session );
        }

        # Retrieve the map table

        $session->get_table( -baseoid => $map,
                             -callback => [\&mapLookupCallback,
                                           $collector, $hosthash, $map] );

        $mapLookupScheduled{$maphash} = 1;

        if( not $snmpV1Hosts{$hosthash} )
        {
            $mapsExpire{$maphash} =
                int( time() + $mapsRefreshPeriod +
                     rand( $mapsRefreshPeriod * $mapsRefreshRandom ) );
        }
        
        return $ret;
    }

    if( defined( $key ) )
    {
        my $value = $maps{$hosthash}{$map}{$key};
        if( not defined $value )
        {
            Error("Cannot find value $key in map $map for $hosthash in ".
                  $collector->path($token));
            if( defined ( $maps{$hosthash}{$map} ) )
            {
                Error("Current map follows");
                while( my($key, $val) = each
                       %{$maps{$hosthash}{$map}} )
                {
                    Error("'$key' => '$val'");
                }
            }
            return 'notfound';
        }
        else
        {
            if( not $snmpV1Hosts{$hosthash} )
            {
                $cref->{'mapsDependentTokens'}{$maphash}{$token} = 1;
                $cref->{'mapsRelatedMaps'}{$token}{$maphash} = 1;
            }
            
            return $value;
        }
    }
    else
    {
        return undef;
    }
}


sub mapLookupCallback
{
    my $session = shift;
    my $collector = shift;
    my $hosthash = shift;
    my $map = shift;

    &Torrus::DB::checkInterrupted();
    
    Debug('Received mapping PDU from ' . $hosthash);

    my $result = $session->var_bind_list();
    if( defined $result )
    {
        my $preflen = length($map) + 1;
        
        while( my( $oid, $key ) = each %{$result} )
        {
            my $val = substr($oid, $preflen);
            $maps{$hosthash}{$map}{$key} = $val;
            # Debug("Map $map discovered: '$key' -> '$val'");
        }
    }
    else
    {
        Error("Error retrieving table $map from $hosthash: " .
              $session->error());
        $session->close();
        probablyDead( $collector, $hosthash );
        return undef;
    }    
}

sub activeMappingSessions
{
    return scalar( @mappingSessions );
}
    
# The target host is unreachable. We try to reach it few more times and
# give it the final diagnose.

sub probablyDead
{
    my $collector = shift;
    my $hosthash = shift;

    my $cref = $collector->collectorData( 'snmp' );

    # Stop all collection for this host, until next initTargetAttributes
    # is successful
    delete $cref->{'activehosts'}{$hosthash};

    my $probablyAlive = 1;

    if( defined( $hostUnreachableSeen{$hosthash} ) )
    {
        if( $Torrus::Collector::SNMP::unreachableTimeout > 0 and
            time() -
            $hostUnreachableSeen{$hosthash} >
            $Torrus::Collector::SNMP::unreachableTimeout )
        {
            $probablyAlive = 0;
        }
    }
    else
    {
        $hostUnreachableSeen{$hosthash} = time();

        if( defined( $db_failures ) )
        {
            $db_failures->host_failure('unreachable', $hosthash);
            $db_failures->set_counter('unreachable',
                                      scalar( keys %hostUnreachableSeen));
        }
    }

    if( $probablyAlive )
    {
        Info('Target host is unreachable. Will try again later: ' . $hosthash);
    }
    else
    {
        # It is dead indeed. Delete all tokens associated with this host
        Info('Target host is unreachable during last ' .
             $Torrus::Collector::SNMP::unreachableTimeout .
             ' seconds. Giving it up: ' . $hosthash);
        my @deleteTargets = ();
        while( my ($oid, $ref1) =
               each %{$cref->{'targets'}{$hosthash}} )
        {
            while( my ($token, $dummy) = each %{$ref1} )
            {
                push( @deleteTargets, $token );
            }
        }
        
        Debug('Deleting ' . scalar( @deleteTargets ) . ' tokens');
        foreach my $token ( @deleteTargets )
        {
            $collector->deleteTarget($token);
        }
                
        delete $hostUnreachableSeen{$hosthash};
        delete $hostUnreachableRetry{$hosthash};
        $unreachableHostDeleted{$hosthash} = 1;

        if( defined( $db_failures ) )
        {
            $db_failures->host_failure('deleted', $hosthash);
            $db_failures->set_counter('unreachable',
                                      scalar( keys %hostUnreachableSeen));
            $db_failures->set_counter('deleted',
                                      scalar( keys %unreachableHostDeleted));
        }
    }
    
    return $probablyAlive;
}

# Return false if the try is too early

sub checkUnreachableRetry
{
    my $collector = shift;
    my $hosthash = shift;

    my $cref = $collector->collectorData( 'snmp' );

    my $ret = 1;
    if( $hostUnreachableSeen{$hosthash} )
    {
        my $lastRetry = $hostUnreachableRetry{$hosthash};

        if( not defined( $lastRetry ) )
        {
            $lastRetry = $hostUnreachableSeen{$hosthash};
        }
            
        if( time() < $lastRetry +
            $Torrus::Collector::SNMP::unreachableRetryDelay )
        {
            $ret = 0;
        }
        else
        {
            $hostUnreachableRetry{$hosthash} = time();
        }            
    }
    
    return $ret;
}


sub isHostDead
{
    my $collector = shift;
    my $hosthash = shift;

    my $cref = $collector->collectorData( 'snmp' );
    return $unreachableHostDeleted{$hosthash};
}


sub hostReachableAgain
{
    my $collector = shift;
    my $hosthash = shift;
    
    my $cref = $collector->collectorData( 'snmp' );
    if( exists( $hostUnreachableSeen{$hosthash} ) )
    {
        delete $hostUnreachableSeen{$hosthash};
        if( defined( $db_failures ) )
        {
            $db_failures->remove_host($hosthash);            
            $db_failures->set_counter('unreachable',
                                      scalar( keys %hostUnreachableSeen));
        }
    }
}


# Callback executed by Collector

sub deleteTarget
{
    my $collector = shift;
    my $token = shift;

    my $tref = $collector->tokenData( $token );
    my $cref = $collector->collectorData( 'snmp' );

    my $hosthash = $tref->{'hosthash'};    
    my $oid = $tref->{'oid'};

    delete $cref->{'targets'}{$hosthash}{$oid}{$token};
    if( not %{$cref->{'targets'}{$hosthash}{$oid}} )
    {
        delete $cref->{'targets'}{$hosthash}{$oid};

        if( not %{$cref->{'targets'}{$hosthash}} )
        {
            delete $cref->{'targets'}{$hosthash};
        }
    }

    delete $cref->{'needsRemapping'}{$token};
    
    foreach my $maphash ( keys %{$cref->{'mapsRelatedMaps'}{$token}} )
    {
        delete $cref->{'mapsDependentTokens'}{$maphash}{$token};
    }
    delete $cref->{'mapsRelatedMaps'}{$token};
}

# Main collector cycle

$Torrus::Collector::runCollector{'snmp'} =
    \&Torrus::Collector::SNMP::runCollector;

sub runCollector
{
    my $collector = shift;
    my $cref = shift;

    # Info(sprintf('runCollector() Offset: %d, active hosts: %d, maps: %d',
    #              $collector->offset(),
    #              scalar( keys %{$cref->{'activehosts'}} ),
    #              scalar(keys %maps)));
    
    # Create one SNMP session per host address.
    # We assume that version, timeout and retries are the same
    # within one address

    # We limit the number of sessions per snmp_dispatcher run
    # because of some strange bugs: with more than 400 sessions per
    # dispatcher, some requests are not sent out

    my @hosts = keys %{$cref->{'activehosts'}};
    
    while( scalar(@mappingSessions) + scalar(@hosts) > 0 )
    {
        my @batch = ();
        while( ( scalar(@mappingSessions) + scalar(@batch) <
                 $Torrus::Collector::SNMP::maxSessionsPerDispatcher )
               and
               scalar(@hosts) > 0 )
        {
            push( @batch, pop( @hosts ) );
        }

        &Torrus::DB::checkInterrupted();

        my @sessions;

        foreach my $hosthash ( @batch )
        {
            my @oids = sort keys %{$cref->{'targets'}{$hosthash}};

            # Info(sprintf('Host %s: %d OIDs',
            #              $hosthash,
            #              scalar(@oids)));
            
            # Find one representative token for the host
            
            if( scalar( @oids ) == 0 )
            {
                next;
            }
        
            my @reptokens = keys %{$cref->{'targets'}{$hosthash}{$oids[0]}};
            if( scalar( @reptokens ) == 0 )
            {
                next;
            }
            my $reptoken = $reptokens[0];
            
            my $session =
                openNonblockingSession( $collector, $reptoken, $hosthash );
            
            &Torrus::DB::checkInterrupted();
            
            if( not defined($session) )
            {
                next;
            }
            else
            {
                Debug('Created SNMP session for ' . $hosthash);
                push( @sessions, $session );
            }
            
            my $oids_per_pdu = $cref->{'oids_per_pdu'}{$hosthash};

            my @pdu_oids = ();
            my $delay = 0;
            
            while( scalar( @oids ) > 0 )
            {
                my $oid = shift @oids;
                push( @pdu_oids, $oid );

                if( scalar( @oids ) == 0 or
                    ( scalar( @pdu_oids ) >= $oids_per_pdu ) )
                {
                    if( not $cref->{'nosysuptime'}{$hosthash} )
                    {
                        # We insert sysUpTime into every PDU, because
                        # we need it in further processing
                        push( @pdu_oids, $sysUpTime );
                    }
                    
                    if( Torrus::Log::isDebug() )
                    {
                        Debug('Sending SNMP PDU to ' . $hosthash . ':');
                        foreach my $oid ( @pdu_oids )
                        {
                            Debug($oid);
                        }
                    }

                    # Generate the list of tokens that form this PDU
                    my $pdu_tokens = {};
                    foreach my $oid ( @pdu_oids )
                    {
                        if( defined( $cref->{'targets'}{$hosthash}{$oid} ) )
                        {
                            foreach my $token
                                ( keys %{$cref->{'targets'}{$hosthash}{$oid}} )
                            {
                                $pdu_tokens->{$oid}{$token} = 1;
                            }
                        }
                    }
                    my $result =
                        $session->
                        get_request( -delay => $delay,
                                     -callback =>
                                     [ \&Torrus::Collector::SNMP::callback,
                                       $collector, $pdu_tokens, $hosthash ],
                                     -varbindlist => \@pdu_oids );
                    if( not defined $result )
                    {
                        Error("Cannot create SNMP request: " .
                              $session->error);
                    }
                    @pdu_oids = ();
                    $delay += 0.01;
                }
            }
        }
        
        &Torrus::DB::checkInterrupted();
        
        snmp_dispatcher();

        # Check if there were pending map lookup sessions
        
        if( scalar( @mappingSessions ) > 0 )
        {
            @mappingSessions = ();
            %mapLookupScheduled = ();
        }
    }
}


sub callback
{
    my $session = shift;
    my $collector = shift;
    my $pdu_tokens = shift;
    my $hosthash = shift;

    &Torrus::DB::checkInterrupted();
    
    my $cref = $collector->collectorData( 'snmp' );

    Debug('SNMP Callback executed for ' . $hosthash);

    if( not defined( $session->var_bind_list() ) )
    {
        Error('SNMP Error for ' . $hosthash . ': ' . $session->error() .
              ' when retrieving ' . join(' ', sort keys %{$pdu_tokens}));

        probablyDead( $collector, $hosthash );
        
        # Clear the mapping
        delete $maps{$hosthash};
        foreach my $oid ( keys %{$pdu_tokens} )
        {
            foreach my $token ( keys %{$pdu_tokens->{$oid}} )
            {
                $cref->{'needsRemapping'}{$token} = 1;
            }
        }
        return;
    }
    else
    {
        hostReachableAgain( $collector, $hosthash );
    }

    my $timestamp = time();

    my $checkUptime = not $cref->{'nosysuptime'}{$hosthash};
    my $doSetValue = 1;
    
    my $uptime = 0;

    if( $checkUptime )
    {
        my $uptimeTicks = $session->var_bind_list()->{$sysUpTime};
        if( defined $uptimeTicks )
        {
            $uptime = $uptimeTicks / 100;
            Debug('Uptime: ' . $uptime);
        }
        else
        {
            Error('Did not receive sysUpTime for ' . $hosthash);
        }

        if( $uptime < $collector->period() or
            ( defined($cref->{'knownUptime'}{$hosthash})
              and
              $uptime + $collector->period() <
              $cref->{'knownUptime'}{$hosthash} ) )
        {
            # The agent has reloaded. Clean all maps and push UNDEF
            # values to the storage
            
            Info('Agent rebooted: ' . $hosthash);
            delete $maps{$hosthash};

            $timestamp -= $uptime;
            foreach my $oid ( keys %{$pdu_tokens} )
            {
                foreach my $token ( keys %{$pdu_tokens->{$oid}} )
                {
                    $collector->setValue( $token, 'U', $timestamp, $uptime );
                    $cref->{'needsRemapping'}{$token} = 1;
                }
            }
            
            $doSetValue = 0;
        }
        $cref->{'knownUptime'}{$hosthash} = $uptime;
    }
    
    if( $doSetValue )
    {
        while( my ($oid, $value) = each %{ $session->var_bind_list() } )
        {
            # Debug("OID=$oid, VAL=$value");
            if( $value eq 'noSuchObject' or
                $value eq 'noSuchInstance' or
                $value eq 'endOfMibView' )
            {
                if( not $cref->{'ignoremiberrors'}{$hosthash}{$oid} )
                {
                    Error("Error retrieving $oid from $hosthash: $value");
                    
                    foreach my $token ( keys %{$pdu_tokens->{$oid}} )
                    {
                        if( defined( $db_failures ) )
                        {
                            $db_failures->mib_error
                                ($hosthash, $collector->path($token));
                        }

                        $collector->deleteTarget($token);
                    }
                }
            }
            else
            {
                if( $cref->{'64bit_oid'}{$oid} )
                {
                    $value = Math::BigInt->new($value);
                }

                foreach my $token ( keys %{$pdu_tokens->{$oid}} )
                {
                    $collector->setValue( $token, $value,
                                          $timestamp, $uptime );
                }
            }
        }
    }
}


# Execute this after the collector has finished

$Torrus::Collector::postProcess{'snmp'} =
    \&Torrus::Collector::SNMP::postProcess;

sub postProcess
{
    my $collector = shift;
    my $cref = shift;

    # It could happen that postProcess is called for a collector which
    # has no targets, and therefore it's the only place where we can
    # initialize these variables
    
    if( not defined( $cref->{'mapsLastExpireChecked'} ) )
    {
        $cref->{'mapsLastExpireChecked'} = 0;
    }

    if( not defined( $cref->{'mapsRefreshed'} ) )
    {
        $cref->{'mapsRefreshed'} = [];
    }
    
    # look if some maps are ready after last expiration check
    if( scalar( @{$cref->{'mapsRefreshed'}} ) > 0 )
    {
        foreach my $maphash ( @{$cref->{'mapsRefreshed'}} )
        {
            foreach my $token
                ( keys %{$cref->{'mapsDependentTokens'}{$maphash}} )
            {
                $cref->{'needsRemapping'}{$token} = 1;
            }
        }
        $cref->{'mapsRefreshed'} = [];
    }

    my $now = time();
    
    if( $cref->{'mapsLastExpireChecked'} + $mapsExpireCheckPeriod <= $now )
    {
        $cref->{'mapsLastExpireChecked'} = $now;
        
        # Check the maps expiration and arrange lookup for expired
        
        while( my ( $maphash, $expire ) = each %mapsExpire )
        {
            if( $expire <= $now and not $mapLookupScheduled{$maphash} )
            {
                &Torrus::DB::checkInterrupted();

                my ( $hosthash, $map ) = split( /\#/o, $maphash );

                if( $unreachableHostDeleted{$hosthash} )
                {
                    # This host is no longer polled. Remove the leftovers
                    
                    delete $mapsExpire{$maphash};
                    delete $maps{$hosthash};
                }
                else
                {
                    # Find one representative token for the map
                    my @tokens =
                        keys %{$cref->{'mapsDependentTokens'}{$maphash}};
                    if( scalar( @tokens ) == 0 )
                    {
                        next;
                    }
                    my $reptoken = $tokens[0];

                    # save the map for the time of refresh                    
                    $oldMaps{$hosthash}{$map} = $maps{$hosthash}{$map};
                    delete $maps{$hosthash}{$map};

                    # this will schedule the map retrieval for the next
                    # collector cycle
                    Debug('Refreshing map: ' . $maphash);
                
                    lookupMap( $collector, $reptoken,
                               $hosthash, $map, undef );

                    # After the next collector period, the maps will be
                    # ready and tokens may be updated without losing the data
                    push( @{$cref->{'mapsRefreshed'}}, $maphash );
                }
            }                
        }
    }
    
    foreach my $token ( keys %{$cref->{'needsRemapping'}} )
    {
        &Torrus::DB::checkInterrupted();

        delete $cref->{'needsRemapping'}{$token};
        if( not Torrus::Collector::SNMP::initTargetAttributes
            ( $collector, $token ) )
        {
            $collector->deleteTarget($token);
        }
    }    
}

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
