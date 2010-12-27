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

# $Id: Paradyne.pm,v 1.1 2010-12-27 00:03:48 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Paradyne devices discovery
# A typical Paradyne device has several slots, and all slots are managed
# through the same IP address, with different community strings.
# That's why you have to configure "Paradyne::slot-name" parameter
# in your discovery file, uniquely for each slot. A slot name should
# not contain special characters.


# Tested with:
#
#   - Paradyne GranDSLAM 2.0 DSLAM - Hotwire DSL;
#     Model: 8000-B2-211; S/W Release : M04.02.27
#
#   - Paradyne Hotwire ATM ADSL Line Card;
#     Model: 8365-B1-000; S/W Release: 02.03.54
#
#   - Paradyne Hotwire ATM G.SHDSL Line Card;
#     Model: 8385-B1-000; S/W Release: 02.03.45
#
#   - Hotwire IP ReachDSL Line Card;
#     Model: 8314-B3-000; S/W Release: 04.03.10


package Torrus::DevDiscover::Paradyne;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'Paradyne'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # PDN-HEADER-MIB
     'paradyne-products'                    => '1.3.6.1.4.1.1795.1.14',
     'xdslDevIfStatsElapsedTimeLinkUp'      =>
     '1.3.6.1.4.1.1795.2.24.2.6.8.1.1.1.1.4'
     );

our $statsInterval;
if( not defined $statsInterval )
{
    $statsInterval = 6; # current15Minutes (GORD)
}


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'paradyne-products',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
    {
        return 0;
    }

    if( length( $devdetails->param('Paradyne::slot-name') ) == 0 )
    {
        Error('Mandatory discovery parameter "Paradyne::slot-number" ' .
              'is not defined for a Paradyne device: ' .
              $devdetails->param('snmp-host') . ':' .
              $devdetails->param('snmp-port') . ':' .
              $devdetails->param('snmp-community'));
        return 0;
    }
    
    $devdetails->setCap('interfaceIndexingManaged');

    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();
    my $session = $dd->session();

    $data->{'nameref'}{'ifReferenceName'} = 'ifName';
    $data->{'nameref'}{'ifSubtreeName'} = 'ifNameT';
    $data->{'param'}{'ifindex-table'} = '$ifName';
    $data->{'nameref'}{'ifNick'} = 'ParadyneIfNick';

    $data->{'nameref'}{'ifComment'} = 'ifDescr';

    if( not defined( $data->{'param'}{'snmp-oids-per-pdu'} ) )
    {
        $data->{'param'}{'snmp-oids-per-pdu'} = '10';
    }
    
    my $slot = $devdetails->param('Paradyne::slot-name');    
    foreach my $ifIndex ( keys %{$data->{'interfaces'}} )
    {
        my $interface = $data->{'interfaces'}{$ifIndex};
        $interface->{'ParadyneIfNick'} =
            $slot . '_' . $interface->{'ifNameT'};
    }
    
    my $xdslOID = $dd->oiddef('xdslDevIfStatsElapsedTimeLinkUp');

    my $xdslTable = $session->get_table( -baseoid => $xdslOID );
    if( defined $xdslTable )
    {
        $devdetails->storeSnmpVars( $xdslTable );
        $devdetails->setCap('paradyneXDSL');

        foreach my $ifIndex ( keys %{$data->{'interfaces'}} )
        {
            if( $devdetails->hasOID( $xdslOID .'.'. $ifIndex .'.'.
                                     $statsInterval ) )
            {
                push( @{$data->{'paradyneXDSLInterfaces'}}, $ifIndex );
            }
        }
    }

    return 1;
}


# Nothing really to do yet
sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    if( $devdetails->hasCap('paradyneXDSL') )
    {
        my $subtreeName = 'XDSL_Line_Stats';

        my $param = {
            'precedence'           => '-600',
            'comment'              => 'Paradyne XDSL line statistics',
            'xdsl-stats-interval'  => $statsInterval
            };
        my $subtreeNode = $cb->addSubtree( $devNode, $subtreeName, $param );

        my $data = $devdetails->data();

        foreach my $ifIndex
            ( sort {$a<=>$b} @{$data->{'paradyneXDSLInterfaces'}} )
        {
            my $interface = $data->{'interfaces'}{$ifIndex};

            my $ifSubtreeName =
                $interface->{$data->{'nameref'}{'ifSubtreeName'}};

            my $templates = ['Paradyne::paradyne-xdsl-interface'];

            my $param = {
                'interface-name' => $interface->{'param'}{'interface-name'},
                'interface-nick' => $interface->{'param'}{'interface-nick'},
                'comment'        => $interface->{'param'}{'comment'}
            };

            $cb->addSubtree( $subtreeNode, $ifSubtreeName,
                             $param, $templates );
        }
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
