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

# $Id: CiscoCatOS.pm,v 1.1 2010-12-27 00:03:55 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Cisco CatOS devices discovery
# To do:
#    Power supply and temperature monitoring
#    RAM monitoring

package Torrus::DevDiscover::CiscoCatOS;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'CiscoCatOS'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # CISCO-SMI
     'ciscoWorkgroup'                    => '1.3.6.1.4.1.9.5',
     # CISCO-STACK-MIB
     'CISCO-STACK-MIB::portName'         => '1.3.6.1.4.1.9.5.1.4.1.1.4',
     'CISCO-STACK-MIB::portIfIndex'      => '1.3.6.1.4.1.9.5.1.4.1.1.11',
     'CISCO-STACK-MIB::chassisSerialNumberString' =>
     '1.3.6.1.4.1.9.5.1.2.19.0'
     );


# Not all interfaces are normally needed to monitor.
# You may override the interface filtering in devdiscover-siteconfig.pl:
# redefine $Torrus::DevDiscover::CiscoCatOS::interfaceFilter
# or define $Torrus::DevDiscover::CiscoCatOS::interfaceFilterOverlay

our $interfaceFilter;
our $interfaceFilterOverlay;
my %catOsInterfaceFilter;

if( not defined( $interfaceFilter ) )
{
    $interfaceFilter = \%catOsInterfaceFilter;
}


# Key is some unique symbolic name, does not mean anything
# ifType is the number to match the interface type
# ifDescr is the regexp to match the interface description
%catOsInterfaceFilter =
    (
     'VLAN N' => {
         'ifType'  => 53,                     # propVirtual
         'ifDescr' => '^VLAN\s+\d+'
         },
     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'ciscoWorkgroup',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
    {
        return 0;
    }

    &Torrus::DevDiscover::RFC2863_IF_MIB::addInterfaceFilter
        ($devdetails, $interfaceFilter);

    if( defined( $interfaceFilterOverlay ) )
    {
        &Torrus::DevDiscover::RFC2863_IF_MIB::addInterfaceFilter
            ($devdetails, $interfaceFilterOverlay);
    }

    $devdetails->setCap('interfaceIndexingManaged');

    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    $data->{'nameref'}{'ifReferenceName'} = 'ifName';
    $data->{'nameref'}{'ifSubtreeName'} = 'ifNameT';
    $data->{'param'}{'ifindex-table'} = '$ifName';

    $data->{'nameref'}{'ifComment'} = 'portName';
    
    # Retrieve port descriptions from CISCO-STACK-MIB

    my $portIfIndexOID = $dd->oiddef('CISCO-STACK-MIB::portIfIndex');
    my $portNameOID = $dd->oiddef('CISCO-STACK-MIB::portName');

    my $portIfIndex = $session->get_table( -baseoid => $portIfIndexOID );
    if( defined $portIfIndex )
    {
        $devdetails->storeSnmpVars( $portIfIndex );

        my $portName = $session->get_table( -baseoid => $portNameOID );
        if( defined $portName )
        {
            foreach my $portIndex
                ( $devdetails->getSnmpIndices( $portIfIndexOID ) )
            {
                my $ifIndex =
                    $devdetails->snmpVar( $portIfIndexOID .'.'. $portIndex );
                my $interface = $data->{'interfaces'}{$ifIndex};

                $interface->{'portName'} =
                    $portName->{$portNameOID .'.'. $portIndex};
            }
        }        
    }

    # In large installations, only named ports may be of interest
    if( $devdetails->param('CiscoCatOS::suppress-noname-ports') eq 'yes' )
    {
        my $nExcluded = 0;
        foreach my $ifIndex ( keys %{$data->{'interfaces'}} )
        {
            my $interface = $data->{'interfaces'}{$ifIndex};
            if( not defined( $interface->{'portName'} ) or
                length( $interface->{'portName'} ) == 0 )
            {
                $interface->{'excluded'} = 1;
                $nExcluded++;
            }            
        }
        Debug('Excluded ' . $nExcluded . ' catalyst ports with empty names');
    }

    my $chassisSerial =
        $dd->retrieveSnmpOIDs( 'CISCO-STACK-MIB::chassisSerialNumberString' );
    if( defined( $chassisSerial ) )
    {
        if( defined( $data->{'param'}{'comment'} ) )
        {
            $data->{'param'}{'comment'} .= ', ';
        }
        $data->{'param'}{'comment'} .= 'Hw Serial#: ' .
            $chassisSerial->{'CISCO-STACK-MIB::chassisSerialNumberString'};
    }
    
    return 1;
}


# Nothing really to do yet
sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
