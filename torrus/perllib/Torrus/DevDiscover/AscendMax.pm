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

# $Id: AscendMax.pm,v 1.1 2010-12-27 00:03:53 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Ascend (Lucent) MAX device discovery.

# Tested with:
#
# MAX 4000, TAOS version 7.0.26

# NOTE: SNMP version 1 is only supported. Because of version 1 and numerous
# WAN DS0 interfaces, the discovery process may take few minutes.

package Torrus::DevDiscover::AscendMax;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'AscendMax'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # ASCEND-MIB
     'ASCEND-MIB::max' => '1.3.6.1.4.1.529.1.2',
     # ASCEND-ADVANCED-AGENT-MIB
     'ASCEND-ADVANCED-AGENT-MIB::wanLineTable' =>
     '1.3.6.1.4.1.529.4.21',
     'ASCEND-ADVANCED-AGENT-MIB::wanLineState' =>
     '1.3.6.1.4.1.529.4.21.1.5',
     'ASCEND-ADVANCED-AGENT-MIB::wanLineActiveChannels' =>
     '1.3.6.1.4.1.529.4.21.1.7',
     'ASCEND-ADVANCED-AGENT-MIB::wanLineSwitchedChannels' =>
     '1.3.6.1.4.1.529.4.21.1.13'
     );

# Not all interfaces are normally needed to monitor.
# You may override the interface filtering in devdiscover-siteconfig.pl:
# redefine $Torrus::DevDiscover::AscendMax::interfaceFilter
# or define $Torrus::DevDiscover::AscendMax::interfaceFilterOverlay

our $interfaceFilter;
our $interfaceFilterOverlay;
my %ascMaxInterfaceFilter;

if( not defined( $interfaceFilter ) )
{
    $interfaceFilter = \%ascMaxInterfaceFilter;
}


# Key is some unique symbolic name, does not mean anything
# ifType is the number to match the interface type
# ifDescr is the regexp to match the interface description
%ascMaxInterfaceFilter =
    (
     'Console' => {
         'ifType'  => 33                      # rs232
         },
     'E1' => {
         'ifType'  => 19                      # e1
         },
     'wan_activeN' => {
         'ifType'  => 23,                     # ppp
         'ifDescr'  => '^wan\d+'
         },
     'wan_inactiveN' => {
         'ifType'  => 1,                      # other
         'ifDescr'  => '^wan\d+'
         },
     'wanidleN' => {
         'ifType'  => 1,                      # other
         'ifDescr'  => '^wanidle\d+'
         },
     'loopbacks' => {
         'ifType'  => 24                      # softwareLoopback
         }
     );


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'ASCEND-MIB::max',
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

    my $wanTableOid = $dd->oiddef('ASCEND-ADVANCED-AGENT-MIB::wanLineTable' );
    my $stateOid =
        $dd->oiddef('ASCEND-ADVANCED-AGENT-MIB::wanLineState' );
    my $totalOid =
        $dd->oiddef('ASCEND-ADVANCED-AGENT-MIB::wanLineSwitchedChannels' );

    my $wanTable =  $session->get_table( -baseoid => $wanTableOid );
    if( defined( $wanTable ) )
    {
        $devdetails->storeSnmpVars( $wanTable );
        $devdetails->setCap('wanLineTable');

        $data->{'ascend_wanLines'} = {};

        foreach my $ifIndex ( $devdetails->getSnmpIndices( $stateOid ) )
        {
            # Check if the line State is 13(active)
            if( $devdetails->snmpVar( $stateOid . '.' . $ifIndex) == 13 )
            {
                my $descr = $devdetails->snmpVar($dd->oiddef('ifDescr') .
                                                 '.' . $ifIndex);

                $data->{'ascend_wanLines'}{$ifIndex}{'description'} = $descr;
                $data->{'ascend_wanLines'}{$ifIndex}{'channels'} =
                    $devdetails->snmpVar( $totalOid . '.' . $ifIndex );
            }
        }
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my $data = $devdetails->data();

    my $callStatsNode = $cb->addSubtree( $devNode, 'Call_Statistics', undef,
                                         ['AscendMax::ascend-totalcalls']);

    foreach my $ifIndex ( sort {$a<=>$b} keys %{$data->{'ascend_wanLines'}} )
    {
        my $param = {};
        $param->{'precedence'} = sprintf('%d', -10000 - $ifIndex);
        $param->{'ascend-ifidx'} = $ifIndex;

        my $nChannels = $data->{'ascend_wanLines'}{$ifIndex}{'channels'};
        $param->{'upper-limit'} = $nChannels;
        $param->{'graph-upper-limit'} = $nChannels;

        my $subtreeName = $data->{'ascend_wanLines'}{$ifIndex}{'description'};
        $subtreeName =~ s/\W/_/g;

        $cb->addLeaf( $callStatsNode, $subtreeName, $param,
                      ['AscendMax::ascend-line-stats']);
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
