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

# $Id: Xylan.pm,v 1.1 2010-12-27 00:03:50 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Xylan (Alcatel) switch discovery.

# Tested with:
#
# Xylan OmniSwitch 9x
# Xylan OmniStack 5024
# Switch software: X/OS 4.3.3
#
# Virtual ports are not processed yet


package Torrus::DevDiscover::Xylan;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'Xylan'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # XYLAN-BASE-MIB
     'xylanSwitchDevice'           => '1.3.6.1.4.1.800.3.1.1',
     # PORT-MIB::phyPortTable
     'xylanPhyPortTable'           => '1.3.6.1.4.1.800.2.3.3.1',
     # PORT-MIB::phyPortDescription
     'xylanPhyPortDescription'     => '1.3.6.1.4.1.800.2.3.3.1.1.4',
     # PORT-MIB::phyPortToInterface
     'xylanPhyPortToInterface'     => '1.3.6.1.4.1.800.2.3.3.1.1.19'
     );

# Not all interfaces are normally needed to monitor.
# You may override the interface filtering in devdiscover-siteconfig.pl:
# redefine $Torrus::DevDiscover::Xylan::interfaceFilter
# or define $Torrus::DevDiscover::Xylan::interfaceFilterOverlay

our $interfaceFilter;
our $interfaceFilterOverlay;
my %xylInterfaceFilter;

if( not defined( $interfaceFilter ) )
{
    $interfaceFilter = \%xylInterfaceFilter;
}


# Key is some unique symbolic name, does not mean anything
# ifType is the number to match the interface type
# ifDescr is the regexp to match the interface description
%xylInterfaceFilter =
    (
     'vnN' => {
         'ifType'  => 53                     # propVirtual
         },
     'loN' => {
         'ifType'  => 24                     # softwareLoopback
         }
     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'xylanSwitchDevice',
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

    $devdetails->setCap('interfaceIndexingPersistent');

    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();
    my $session = $dd->session();

    $data->{'nameref'}{'ifNick'}        = 'xylanInterfaceNick';
    $data->{'nameref'}{'ifSubtreeName'} = 'xylanInterfaceNick';
    $data->{'nameref'}{'ifComment'}     = 'xylanInterfaceComment';
    $data->{'nameref'}{'ifReferenceName'}   = 'xylanInterfaceHumanName';
    
    my $phyPortTable =
        $session->get_table( -baseoid => $dd->oiddef('xylanPhyPortTable') );

    if( not defined $phyPortTable )
    {
        Error('Error retrieving PORT-MIB::phyPortTable from Xylan device');
        return 0;
    }

    $devdetails->storeSnmpVars( $phyPortTable );

    foreach my $slotDotPort
        ( $devdetails->
          getSnmpIndices( $dd->oiddef('xylanPhyPortDescription') ) )
    {
        my ( $slot, $port ) = split( '\.', $slotDotPort );

        my $ifIndex =
            $devdetails->snmpVar($dd->oiddef('xylanPhyPortToInterface') .
                                 '.' . $slotDotPort);
        my $interface = $data->{'interfaces'}{$ifIndex};

        if( defined $interface )
        {
            $interface->{'xylanInterfaceNick'} =
                sprintf( '%d_%d', $slot, $port );

            $interface->{'xylanInterfaceHumanName'} =
                sprintf( '%d/%d', $slot, $port );

            $interface->{'xylanInterfaceComment'} =
                $devdetails->snmpVar($dd->oiddef('xylanPhyPortDescription') .
                                     '.' . $slotDotPort);
        }
    }

    # verify if all interfaces are processed

    foreach my $ifIndex ( keys %{$data->{'interfaces'}} )
    {
        my $interface = $data->{'interfaces'}{$ifIndex};

        if( not defined( $interface->{'xylanInterfaceNick'} ) )
        {
            Warn('Interface ' . $ifIndex . ' is not in phyPortTable');

            my $nick = sprintf( 'PORT%d', $ifIndex );
            $interface->{'xylanInterfaceNick'} = $nick;
            $interface->{'xylanInterfaceHumanName'} = $nick;

            $interface->{'xylanInterfaceComment'} = $interface->{'ifDescr'};
        }
    }

    return 1;
}


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
