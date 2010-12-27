#  Copyright (C) 2002-2010  Stanislav Sinyagin
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

# $Id: DevDiscover.pm,v 1.1 2010-12-27 00:03:43 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Core SNMP device discovery module

package Torrus::DevDiscover::DevDetails;

package Torrus::DevDiscover;

use strict;
use POSIX qw(strftime);
use Net::SNMP qw(:snmp :asn1);
use Digest::MD5 qw(md5);

use Torrus::Log;

BEGIN
{
    foreach my $mod ( @Torrus::DevDiscover::loadModules )
    {
        eval( 'require ' . $mod );
        die( $@ ) if $@;
    }
}

# Custom overlays for templates
# overlayName ->
#     'Module::templateName' -> { 'name' => 'templateName',
#                                 'source' => 'filename.xml' }
our %templateOverlays;

our @requiredParams =
    (
     'snmp-port',
     'snmp-version',
     'snmp-timeout',
     'snmp-retries',
     'data-dir',
     'snmp-host'
     );

our %defaultParams;

$defaultParams{'rrd-hwpredict'} = 'no';
$defaultParams{'domain-name'} = '';
$defaultParams{'host-subtree'} = '';
$defaultParams{'snmp-check-sysuptime'} = 'yes';
$defaultParams{'show-recursive'} = 'yes';
$defaultParams{'snmp-ipversion'} = '4';
$defaultParams{'snmp-transport'} = 'udp';

our @copyParams =
    ( 'collector-period',
      'collector-timeoffset',
      'collector-dispersed-timeoffset',
      'collector-timeoffset-min',
      'collector-timeoffset-max',
      'collector-timeoffset-step',
      'comment',
      'domain-name',
      'monitor-period',
      'monitor-timeoffset',
      'nodeid-device',
      'show-recursive',
      'snmp-host',
      'snmp-port',
      'snmp-localaddr',
      'snmp-localport',
      'snmp-ipversion',
      'snmp-transport',
      'snmp-community',
      'snmp-version',
      'snmp-username',
      'snmp-authkey',
      'snmp-authpassword',
      'snmp-authprotocol',
      'snmp-privkey',
      'snmp-privpassword',
      'snmp-privprotocol',
      'snmp-timeout',
      'snmp-retries',
      'snmp-oids-per-pdu',
      'snmp-check-sysuptime',
      'snmp-max-msg-size',
      'system-id' );


%Torrus::DevDiscover::oiddef =
    (
     'system'         => '1.3.6.1.2.1.1',
     'sysDescr'       => '1.3.6.1.2.1.1.1.0',
     'sysObjectID'    => '1.3.6.1.2.1.1.2.0',
     'sysUpTime'      => '1.3.6.1.2.1.1.3.0',
     'sysContact'     => '1.3.6.1.2.1.1.4.0',
     'sysName'        => '1.3.6.1.2.1.1.5.0',
     'sysLocation'    => '1.3.6.1.2.1.1.6.0'
     );

my @systemOIDs = ('sysDescr', 'sysObjectID', 'sysUpTime', 'sysContact',
                  'sysName', 'sysLocation');

sub new
{
    my $self = {};
    my $class = shift;
    my %options = @_;
    bless $self, $class;

    $self->{'oiddef'} = {};
    $self->{'oidrev'} = {};

    # Combine all %MODULE::oiddef hashes into one
    foreach my $module ( 'Torrus::DevDiscover',
                         @Torrus::DevDiscover::loadModules )
    {
        while( my($name, $oid) = each %{eval('\%'.$module.'::oiddef')} )
        {
            die( $@ ) if $@;
            $self->{'oiddef'}->{$name} = $oid;
            $self->{'oidrev'}->{$oid} = $name;
        }
    }

    $self->{'datadirs'} = {};
    $self->{'globalData'} = {};

    return $self;
}



sub globalData
{
    my $self = shift;
    return $self->{'globalData'};
}


sub discover
{
    my $self = shift;
    my @paramhashes = @_;

    my $devdetails = new Torrus::DevDiscover::DevDetails();

    foreach my $params ( \%defaultParams, @paramhashes )
    {
        $devdetails->setParams( $params );
    }

    foreach my $param ( @requiredParams )
    {
        if( not defined( $devdetails->param( $param ) ) )
        {
            Error('Required parameter not defined: ' . $param);
            return 0;
        }
    }

    my %snmpargs;
    my $community;
    
    my $version = $devdetails->param( 'snmp-version' );
    $snmpargs{'-version'} = $version;    

    foreach my $arg ( qw(-port -localaddr -localport -timeout -retries) )
    {
        if( defined( $devdetails->param( 'snmp' . $arg ) ) )
        {
            $snmpargs{$arg} = $devdetails->param( 'snmp' . $arg );
        }
    }
    
    $snmpargs{'-domain'} = $devdetails->param('snmp-transport') . '/ipv' .
        $devdetails->param('snmp-ipversion');

    if( $version eq '1' or $version eq '2c' )
    {
        $community = $devdetails->param( 'snmp-community' );
        if( not defined( $community ) )
        {
            Error('Required parameter not defined: snmp-community');
            return 0;
        }
        $snmpargs{'-community'} = $community;

        # set maxMsgSize to a maximum value for better compatibility
        
        my $maxmsgsize = $devdetails->param('snmp-max-msg-size');
        if( defined( $maxmsgsize ) )
        {
            $devdetails->setParam('snmp-max-msg-size', $maxmsgsize);
            $snmpargs{'-maxmsgsize'} = $maxmsgsize;
        }        
    }
    elsif( $version eq '3' )        
    {
        foreach my $arg ( qw(-username -authkey -authpassword -authprotocol
                             -privkey -privpassword -privprotocol) )
        {
            if( defined $devdetails->param( 'snmp' . $arg ) )
            {
                $snmpargs{$arg} = $devdetails->param( 'snmp' . $arg );
            }
        }
        $community = $snmpargs{'-username'};
        if( not defined( $community ) )
        {
            Error('Required parameter not defined: snmp-user');
            return 0;
        }        
    }
    else
    {
        Error('Illegal value for snmp-version parameter: ' . $version);
        return 0;
    }

    my $hostname = $devdetails->param('snmp-host');
    my $domain = $devdetails->param('domain-name');

    if( $domain and index($hostname, '.') < 0 and index($hostname, ':') < 0 )
    {
         $hostname .= '.' . $domain;
    }
    $snmpargs{'-hostname'} = $hostname;

    my $port = $snmpargs{'-port'};
    Debug('Discovering host: ' . $hostname . ':' . $port . ':' . $community);

    my ($session, $error) =
        Net::SNMP->session( %snmpargs,
                            -nonblocking => 0,
                            -translate   => ['-all', 0, '-octetstring', 1] );
    if( not defined($session) )
    {
        Error('Cannot create SNMP session: ' . $error);
        return undef;
    }
    
    my @oids = ();
    foreach my $var ( @systemOIDs )
    {
        push( @oids, $self->oiddef( $var ) );
    }

    # This is the only checking if the remote agent is alive

    my $result = $session->get_request( -varbindlist => \@oids );
    if( defined $result )
    {
        $devdetails->storeSnmpVars( $result );
    }
    else
    {
        # When the remote agent is reacheable, but system objecs are
        # not implemented, we get a positive error_status
        if( $session->error_status() == 0 )
        {
            Error("Unable to communicate with SNMP agent on " . $hostname .
                  ':' . $port . ':' . $community . " - " . $session->error());
            return undef;
        }
    }

    my $data = $devdetails->data();
    $data->{'param'} = {};

    $data->{'templates'} = [];
    my $customTmpl = $devdetails->param('custom-host-templates');
    if( length( $customTmpl ) > 0 )
    {
        push( @{$data->{'templates'}}, split( /\s*,\s*/, $customTmpl ) );
    }
    
    # Build host-level legend
    my %legendValues =
        (
         10 => {
             'name'  => 'Location',
             'value' => $devdetails->snmpVar($self->oiddef('sysLocation'))
             },
         20 => {
             'name'  => 'Contact',
             'value' => $devdetails->snmpVar($self->oiddef('sysContact'))
             },
         30 => {
             'name'  => 'System ID',
             'value' => $devdetails->param('system-id')
             },
         50 => {
             'name'  => 'Description',
             'value' => $devdetails->snmpVar($self->oiddef('sysDescr'))
             }
         );

    if( defined( $devdetails->snmpVar($self->oiddef('sysUpTime')) ) )
    {
        $legendValues{40}{'name'} = 'Uptime';
        $legendValues{40}{'value'} =
            sprintf("%d days since %s",
                    $devdetails->snmpVar($self->oiddef('sysUpTime')) /
                    (100*3600*24),
                    strftime($Torrus::DevDiscover::timeFormat,
                             localtime(time())));
    }
     
    my $legend = '';
    foreach my $key ( sort keys %legendValues )
    {
        my $text = $legendValues{$key}{'value'};
        if( length( $text ) > 0 )
        {
            $text = $devdetails->screenSpecialChars( $text );
            $legend .= $legendValues{$key}{'name'} . ':' . $text . ';';
        }
    }
    
    if( $devdetails->param('suppress-legend') ne 'yes' )
    {
        $data->{'param'}{'legend'} = $legend;
    }

    # some parameters need just one-to-one copying

    my @hostCopyParams =
        split('\s*,\s*', $devdetails->param('host-copy-params'));
    
    foreach my $param ( @copyParams, @hostCopyParams )
    {
        my $val = $devdetails->param( $param );
        if( length( $val ) > 0 )
        {
            $data->{'param'}{$param} = $val;
        }
    }

    # If snmp-host is ipv6 address, system-id needs to be adapted to
    # remove colons
    
    if( not defined( $data->{'param'}{'system-id'} ) and
        index($data->{'param'}{'snmp-host'}, ':') >= 0 )
    {
        my $systemid = $data->{'param'}{'snmp-host'};
        $systemid =~ s/:/_/g;
        $data->{'param'}{'system-id'} = $systemid;
    }

    if( not defined( $devdetails->snmpVar($self->oiddef('sysUpTime')) ) )
    {
        Debug('Agent does not support sysUpTime');
        $data->{'param'}{'snmp-check-sysuptime'} = 'no';
    }

    $data->{'param'}{'data-dir'} =
        $self->genDataDir( $devdetails->param('data-dir'), $hostname );

    # Register the directory for listDataDirs()
    $self->{'datadirs'}{$devdetails->param('data-dir')} = 1;

    $self->{'session'} = $session;

    # some discovery modules need to be disabled on per-device basis

    my %onlyDevtypes;
    my $useOnlyDevtypes = 0;
    foreach my $devtype ( split('\s*,\s*',
                                $devdetails->param('only-devtypes') ) )
    {
        $onlyDevtypes{$devtype} = 1;
        $useOnlyDevtypes = 1;
    }

    my %disabledDevtypes;
    foreach my $devtype ( split('\s*,\s*',
                                $devdetails->param('disable-devtypes') ) )
    {
        $disabledDevtypes{$devtype} = 1;
    }

    # 'checkdevtype' procedures for each known device type return true
    # when it's their device. They also research the device capabilities.
    my $reg = \%Torrus::DevDiscover::registry;
    foreach my $devtype
        ( sort {$reg->{$a}{'sequence'} <=> $reg->{$b}{'sequence'}}
          keys %{$reg} )
    {
        if( ( not $useOnlyDevtypes or $onlyDevtypes{$devtype} ) and
            not $disabledDevtypes{$devtype} and
            &{$reg->{$devtype}{'checkdevtype'}}($self, $devdetails) )
        {
            $devdetails->setDevType( $devtype );
            Debug('Found device type: ' . $devtype);
        }
    }

    my @devtypes = sort {
        $reg->{$a}{'sequence'} <=> $reg->{$b}{'sequence'}
    } $devdetails->getDevTypes();
    $data->{'param'}{'devdiscover-devtypes'} = join(',', @devtypes);

    $data->{'param'}{'devdiscover-nodetype'} = '::device';

    # Do the detailed discovery and prepare data
    my $ok = 1;
    foreach my $devtype ( @devtypes )
    {
        $ok = &{$reg->{$devtype}{'discover'}}($self, $devdetails) ? $ok:0;
    }

    delete $self->{'session'};
    $session->close();

    $devdetails->applySelectors();
        
    my $subtree = $devdetails->param('host-subtree');
    if( not defined( $self->{'devdetails'}{$subtree} ) )
    {
        $self->{'devdetails'}{$subtree} = [];
    }
    push( @{$self->{'devdetails'}{$subtree}}, $devdetails );

    my $define_tokensets = $devdetails->param('define-tokensets');
    if( defined( $define_tokensets ) and length( $define_tokensets ) > 0 )
    {
        foreach my $pair ( split(/\s*;\s*/, $define_tokensets ) )
        {
            my( $tset, $description ) = split( /\s*:\s*/, $pair );
            if( $tset !~ /^[a-z][a-z0-9-_]*$/ )
            {
                Error('Invalid name for tokenset: ' . $tset);
                $ok = 0;
            }
            elsif( length( $description ) == 0 )
            {
                Error('Missing description for tokenset: ' . $tset);
                $ok = 0;
            }
            else
            {
                $self->{'define-tokensets'}{$tset} = $description;
            }
        }
    }
    return $ok;
}


sub buildConfig
{
    my $self = shift;
    my $cb = shift;

    my $reg = \%Torrus::DevDiscover::registry;
        
    foreach my $subtree ( sort keys %{$self->{'devdetails'}} )
    {
        # Chop the first and last slashes
        my $path = $subtree;
        $path =~ s/^\///;
        $path =~ s/\/$//;

        # generate subtree path XML
        my $subtreeNode = undef;
        foreach my $subtreeName ( split( '/', $path ) )
        {
            $subtreeNode = $cb->addSubtree( $subtreeNode, $subtreeName );
        }

        foreach my $devdetails
            ( sort {$a->param('snmp-host') cmp $b->param('snmp-host')}
              @{$self->{'devdetails'}{$subtree}} )
        {

            my $data = $devdetails->data();

            my @registryOverlays = ();
            if( defined( $devdetails->param('template-registry-overlays' ) ) )
            {
                my @overlayNames = 
                    split(/\s*,\s*/,
                          $devdetails->param('template-registry-overlays' ));
                foreach my $overlayName ( @overlayNames )
                {
                    if( defined( $templateOverlays{$overlayName}) )
                    {
                        push( @registryOverlays,
                              $templateOverlays{$overlayName} );
                    }
                    else
                    {
                        Error('Cannot find the template overlay named ' .
                              $overlayName);
                    }
                }
            }

            # we should call this anyway, in order to flush the overlays
            # set by previous host
            $cb->setRegistryOverlays( @registryOverlays );            
            
            if( $devdetails->param('disable-snmpcollector' ) eq 'yes' )
            {
                push( @{$data->{'templates'}}, '::viewonly-defaults' );
            }
            else
            {
                push( @{$data->{'templates'}}, '::snmp-defaults' );
            }

            if( $devdetails->param('rrd-hwpredict' ) eq 'yes' )
            {
                push( @{$data->{'templates'}}, '::holt-winters-defaults' );
            }

            
            my $devNodeName = $devdetails->param('symbolic-name');
            if( length( $devNodeName ) == 0 )
            {
                $devNodeName = $devdetails->param('system-id');
                if( length( $devNodeName ) == 0 )
                {
                    $devNodeName = $devdetails->param('snmp-host');
                }
            }                
                
            my $devNode = $cb->addSubtree( $subtreeNode, $devNodeName,
                                           $data->{'param'},
                                           $data->{'templates'} );

            my $aliases = $devdetails->param('host-aliases');
            if( length( $aliases ) > 0 )
            {
                foreach my $alias ( split( '\s*,\s*', $aliases ) )
                {
                    $cb->addAlias( $devNode, $alias );
                }
            }

            my $includeFiles = $devdetails->param('include-files');
            if( length( $includeFiles ) > 0 )
            {
                foreach my $file ( split( '\s*,\s*', $includeFiles ) )
                {
                    $cb->addFileInclusion( $file );
                }
            }
                    

            # Let the device type-specific modules add children
            # to the subtree
            foreach my $devtype
                ( sort {$reg->{$a}{'sequence'} <=> $reg->{$b}{'sequence'}}
                  $devdetails->getDevTypes() )
            {
                &{$reg->{$devtype}{'buildConfig'}}
                ( $devdetails, $cb, $devNode, $self->{'globalData'} );
            }

            $cb->{'statistics'}{'hosts'}++;
        }
    }

    foreach my $devtype
        ( sort {$reg->{$a}{'sequence'} <=> $reg->{$b}{'sequence'}}
          keys %{$reg} )
    {
        if( defined( $reg->{$devtype}{'buildGlobalConfig'} ) )
        {
            &{$reg->{$devtype}{'buildGlobalConfig'}}($cb,
                                                     $self->{'globalData'});
        }
    }
    
    if( defined( $self->{'define-tokensets'} ) )
    {
        my $tsetsNode = $cb->startTokensets();
        foreach my $tset ( sort keys %{$self->{'define-tokensets'}} )
        {
            $cb->addTokenset( $tsetsNode, $tset, {
                'comment' => $self->{'define-tokensets'}{$tset} } );
        }
    }
}



sub session
{
    my $self = shift;
    return $self->{'session'};
}

sub oiddef
{
    my $self = shift;
    my $var = shift;

    my $ret = $self->{'oiddef'}->{$var};
    if( not $ret )
    {
        Error('Undefined OID definition: ' . $var);
    }
    return $ret;
}


sub oidref
{
    my $self = shift;
    my $oid = shift;
    return $self->{'oidref'}->{$oid};
}


sub genDataDir
{
    my $self = shift;
    my $basedir = shift;
    my $hostname = shift;

    if( $Torrus::DevDiscover::hashDataDirEnabled )
    {
        return $basedir . '/' .
            sprintf( $Torrus::DevDiscover::hashDataDirFormat,
                     unpack('N', md5($hostname)) %
                     $Torrus::DevDiscover::hashDataDirBucketSize );
    }
    else
    {
        return $basedir;
    }
}


sub listDataDirs
{
    my $self = shift;

    my @basedirs = keys %{$self->{'datadirs'}};
    my @ret = @basedirs;

    if( $Torrus::DevDiscover::hashDataDirEnabled )
    {
        foreach my $basedir ( @basedirs )
        {
            for( my $i = 0;
                 $i < $Torrus::DevDiscover::hashDataDirBucketSize;
                 $i++ )
            {
                push( @ret, $basedir . '/' .
                      sprintf( $Torrus::DevDiscover::hashDataDirFormat, $i ) );
            }
        }
    }
    return @ret;
}

##
# Check if SNMP table is present, without retrieving the whole table

sub checkSnmpTable
{
    my $self = shift;
    my $oidname = shift;

    my $session = $self->session();
    my $oid = $self->oiddef( $oidname );

    my $result = $session->get_next_request( -varbindlist => [ $oid ] );
    if( defined( $result ) )
    {
        # check if the returned oid shares the base of the query
        my $firstOid = (keys %{$result})[0];
        if( Net::SNMP::oid_base_match( $oid, $firstOid ) and
            length( $result->{$firstOid} ) > 0 )
        {
            return 1;
        }
    }
    return 0;
}


##
# Check if given OID is present

sub checkSnmpOID
{
    my $self = shift;
    my $oidname = shift;

    my $session = $self->session();
    my $oid = $self->oiddef( $oidname );

    my $result = $session->get_request( -varbindlist => [ $oid ] );
    if( $session->error_status() == 0 and
        defined($result) and
        defined($result->{$oid}) and
        length($result->{$oid}) > 0 )
    {
        return 1;
    }
    return 0;
}


##
# retrieve the given OIDs by names and return hash with values

sub retrieveSnmpOIDs
{
    my $self = shift;
    my @oidnames = @_;

    my $session = $self->session();
    my $oids = [];
    foreach my $oidname ( @oidnames )
    {
        push( @{$oids}, $self->oiddef( $oidname ) );
    }                   

    my $result = $session->get_request( -varbindlist => $oids );
    if( $session->error_status() == 0 and defined( $result ) )
    {
        my $ret = {};
        foreach my $oidname ( @oidnames )
        {
            $ret->{$oidname} = $result->{$self->oiddef( $oidname )};
        }
        return $ret;
    }
    return undef;
}

##
# Simple wrapper for Net::SNMP::oid_base_match

sub oidBaseMatch
{
    my $self = shift;
    my $base_oid = shift;
    my $oid = shift;

    if( $base_oid =~ /^\D/ )
    {
        $base_oid = $self->oiddef( $base_oid );
    }
    return Net::SNMP::oid_base_match( $base_oid, $oid );
}

##
# some discovery modules need to adjust max-msg-size

sub setMaxMsgSize
{
    my $self = shift;
    my $devdetails = shift;
    my $msgsize = shift;
    my $opt = shift;

    $opt = {} unless defined($opt);

    if( (not $opt->{'only_v1_and_v2'}) or $self->session()->version() != 3 )
    {
        $self->session()->max_msg_size($msgsize);
        $devdetails->data()->{'param'}{'snmp-max-msg-size'} = $msgsize;
    }
}

    


###########################################################################
####  Torrus::DevDiscover::DevDetails: the information container for a device
####

package Torrus::DevDiscover::DevDetails;

use strict;
use Torrus::RPN;
use Torrus::Log;

sub new
{
    my $self = {};
    my $class = shift;
    bless $self, $class;

    $self->{'params'}   = {};
    $self->{'snmpvars'} = {}; # SNMP results stored here
    $self->{'devtype'}  = {}; # Device types
    $self->{'caps'}     = {}; # Device capabilities
    $self->{'data'}     = {}; # Discovery data

    return $self;
}


sub setParams
{
    my $self = shift;
    my $params = shift;

    while( my ($param, $value) = each %{$params} )
    {
        $self->{'params'}->{$param} = $value;
    }
}


sub setParam
{
    my $self = shift;
    my $param = shift;
    my $value = shift;

    $self->{'params'}->{$param} = $value;
}


sub param
{
    my $self = shift;
    my $name = shift;
    return $self->{'params'}->{$name};
}


##
# store the query results for later use

sub storeSnmpVars
{
    my $self = shift;
    my $vars = shift;

    while( my( $oid, $value ) = each %{$vars} )
    {
        if( $oid !~ /^\d[0-9.]+\d$/o )
        {
            Error("Invalid OID syntax: '$oid'");
        }
        else
        {
            $self->{'snmpvars'}{$oid} = $value;
            
            while( length( $oid ) > 0 )
            {
                $oid =~ s/\d+$//o;
                $oid =~ s/\.$//o;
                if( not exists( $self->{'snmpvars'}{$oid} ) )
                {
                    $self->{'snmpvars'}{$oid} = undef;
                }
            }
        }
    }

    # Clean the cache of sorted OIDs
    $self->{'sortedoids'} = undef;
}

##
# check if the stored query results have such OID prefix

sub hasOID
{
    my $self = shift;
    my $oid = shift;

    my $found = 0;
    if( exists( $self->{'snmpvars'}{$oid} ) )
    {
        $found = 1;
    }
    return $found;
}

##
# get the value of stored SNMP variable

sub snmpVar
{
    my $self = shift;
    my $oid = shift;
    return $self->{'snmpvars'}{$oid};
}

##
# get the list of table indices for the specified prefix

sub getSnmpIndices
{
    my $self = shift;
    my $prefix = shift;

    # Remember the sorted OIDs, as sorting is quite expensive for large
    # arrays.
    
    if( not defined( $self->{'sortedoids'} ) )
    {
        $self->{'sortedoids'} = [];
        push( @{$self->{'sortedoids'}},
              Net::SNMP::oid_lex_sort( keys %{$self->{'snmpvars'}} ) );
    }
        
    my @ret;
    my $prefixLen = length( $prefix ) + 1;
    my $matched = 0;

    foreach my $oid ( @{$self->{'sortedoids'}} )
    {
        if( defined($self->{'snmpvars'}{$oid} ) )
        {
            if( Net::SNMP::oid_base_match( $prefix, $oid ) )
            {
                # Extract the index from OID
                my $index = substr( $oid, $prefixLen );
                push( @ret, $index );
                $matched = 1;
            }
            elsif( $matched )
            {
                last;
            }
        }
    }
    return @ret;
}


##
# device type is the registered discovery module name

sub setDevType
{
    my $self = shift;
    my $type = shift;
    $self->{'devtype'}{$type} = 1;
}

sub isDevType
{
    my $self = shift;
    my $type = shift;
    return $self->{'devtype'}{$type};
}

sub getDevTypes
{
    my $self = shift;
    return keys %{$self->{'devtype'}};
}

##
# device capabilities. Each discovery module may define its own set of
# capabilities and use them for information exchange between checkdevtype(),
# discover(), and buildConfig() of its own and dependant modules

sub setCap
{
    my $self = shift;
    my $cap = shift;
    Debug('Device capability: ' . $cap);
    $self->{'caps'}{$cap} = 1;
}

sub hasCap
{
    my $self = shift;
    my $cap = shift;
    return $self->{'caps'}{$cap};
}

sub clearCap
{
    my $self = shift;
    my $cap = shift;
    Debug('Clearing device capability: ' . $cap);
    if( exists( $self->{'caps'}{$cap} ) )
    {
        delete $self->{'caps'}{$cap};
    }
}



sub data
{
    my $self = shift;
    return $self->{'data'};
}


sub screenSpecialChars
{
    my $self = shift;
    my $txt = shift;

    $txt =~ s/:/{COLON}/gm;
    $txt =~ s/;/{SEMICOL}/gm;
    $txt =~ s/%/{PERCENT}/gm;

    return $txt;
}


sub applySelectors
{
    my $self = shift;

    my $selList = $self->param('selectors');
    return if not defined( $selList );

    my $reg = \%Torrus::DevDiscover::selectorsRegistry;
    
    foreach my $sel ( split('\s*,\s*', $selList) )
    {
        my $type = $self->param( $sel . '-selector-type' );
        if( not defined( $type ) )
        {
            Error('Parameter ' . $sel . '-selector-type must be defined ' .
                  'for ' . $self->param('snmp-host'));
        }
        elsif( not exists( $reg->{$type} ) )
        {
            Error('Unknown selector type: ' . $type .
                  ' for ' . $self->param('snmp-host'));
        }
        else
        {
            Debug('Initializing selector: ' . $sel);
            
            my $treg = $reg->{$type};
            my @objects = &{$treg->{'getObjects'}}( $self, $type );

            foreach my $object ( @objects )
            {
                Debug('Checking object: ' .
                      &{$treg->{'getObjectName'}}( $self, $object, $type ));

                my $expr = $self->param( $sel . '-selector-expr' );
                $expr = '1' if length( $expr ) == 0;

                my $callback = sub
                {
                    my $attr = shift;
                    my $checkval = $self->param( $sel . '-' . $attr );
                    
                    Debug('Checking attribute: ' . $attr .
                          ' and value: ' . $checkval);
                    my $ret = &{$treg->{'checkAttribute'}}( $self,
                                                            $object, $type,
                                                            $attr, $checkval );
                    Debug(sprintf('Returned value: %d', $ret));
                    return $ret;                    
                };
                
                my $rpn = new Torrus::RPN;
                my $result = $rpn->run( $expr, $callback );
                Debug('Selector result: ' . $result);
                if( $result )
                {
                    my $actions = $self->param( $sel . '-selector-actions' );
                    foreach my $action ( split('\s*,\s*', $actions) )
                    {
                        my $arg =
                            $self->param( $sel . '-' . $action . '-arg' );
                        $arg = 1 if not defined( $arg );
                        
                        Debug('Applying action: ' . $action .
                              ' with argument: ' . $arg);
                        &{$treg->{'applyAction'}}( $self, $object, $type,
                                                   $action, $arg );
                    }
                }
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
