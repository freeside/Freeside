#  Copyright (C) 2003  Shawn Ferry
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

# $Id: CiscoFirewall.pm,v 1.1 2010-12-27 00:03:56 ivan Exp $
# Shawn Ferry <lalartu at obscure dot org> <sferry at sevenspace dot com>

# Cisco Firewall devices discovery

package Torrus::DevDiscover::CiscoFirewall;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'CiscoFirewall'} = {
    'sequence'     => 510,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # CISCO-FIREWALL
     'ciscoFirewallMIB'            => '1.3.6.1.4.1.9.9.147',
     'cfwBasicEventsTableLastRow'  => '1.3.6.1.4.1.9.9.147.1.1.4',
     'cfwConnectionStatTable'      => '1.3.6.1.4.1.9.9.147.1.2.2.2.1',
     'cfwConnectionStatMax'        => '1.3.6.1.4.1.9.9.147.1.2.2.2.1.5.40.7',
     );



sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    if( $devdetails->isDevType('CiscoGeneric') and
        $dd->checkSnmpTable('ciscoFirewallMIB') )
    {
        $devdetails->setCap('interfaceIndexingManaged');
        return 1;
    }

    return 0;
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

    if( not defined( $data->{'param'}{'snmp-oids-per-pdu'} ) )
    {
        my $oidsPerPDU =
            $devdetails->param('CiscoFirewall::snmp-oids-per-pdu');
        if( $oidsPerPDU == 0 )
        {
            $oidsPerPDU = 10;
        }
        $data->{'param'}{'snmp-oids-per-pdu'} = $oidsPerPDU;
    }

    if( $dd->checkSnmpOID('cfwConnectionStatMax') )
    {
        $devdetails->setCap('CiscoFirewall::connections');
    }
    
    # I have not seen a system that supports this.
    if( $dd->checkSnmpOID('cfwBasicEventsTableLastRow') )
    {
        $devdetails->setCap('CiscoFirewall::events');
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    my $data = $devdetails->data();

    my $fwStatsTree = "Firewall_Stats";
    my $fwStatsParam = {
        'precedence' => '-1000',
        'comment'    => 'Firewall Stats',
    };

    my @templates = ('CiscoFirewall::cisco-firewall-subtree');
    
    if( $devdetails->hasCap('CiscoFirewall::connections') )
    {
        push( @templates, 'CiscoFirewall::connections');
    }

    if( $devdetails->hasCap('CiscoFirewall::events') )
    {
        push( @templates, 'CiscoFirewall::events');
    }

    $cb->addSubtree( $devNode, $fwStatsTree, $fwStatsParam, \@templates );
}




1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
