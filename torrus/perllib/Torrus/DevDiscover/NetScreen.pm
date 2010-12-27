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

# $Id: NetScreen.pm,v 1.1 2010-12-27 00:03:50 ivan Exp $
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>

# NetScreen

package Torrus::DevDiscover::NetScreen;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'NetScreen'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

our %oiddef =
    (
     'netscreen'         => '1.3.6.1.4.1.3224',
     'nsResSessMaxium'   => '1.3.6.1.4.1.3224.16.3.3.0',
     'nsIfFlowTable'     => '1.3.6.1.4.1.3224.9.3',

     'nsIfMonTable'      => '1.3.6.1.4.1.3224.9.4',
     'nsIfMonIfIdx'      => '1.3.6.1.4.1.3224.9.4.1.1',
     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->checkSnmpTable( 'netscreen' ) )
    {
        return 0;
    }

    my $data = $devdetails->data();

    $devdetails->setCap('interfaceIndexingManaged');
    
    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    $data->{'nameref'}{'ifDescr'} = '';
    $data->{'param'}{'ifindex-map'} = '$IFIDX_MAC';
    Torrus::DevDiscover::RFC2863_IF_MIB::retrieveMacAddresses( $dd,
                                                               $devdetails );

    # TODO: do something about these tables in buildConfig

    if( $dd->checkSnmpTable( 'nsIfFlowTable' ) )
    {
        $devdetails->setCap('nsIfFlowTable');
    }

    if( $dd->checkSnmpTable( 'nsIfMonTable' ) )
    {
        $devdetails->setCap('nsIfMonTable');
    }

    if( not defined( $data->{'param'}{'snmp-oids-per-pdu'} ) )
    {
        my $oidsPerPDU = $devdetails->param('NetScreen::snmp-oids-per-pdu');
        if( $oidsPerPDU == 0 )
        {
            $oidsPerPDU = 10;
        }
        Debug("Setting snmp-oids-per-pdu to $oidsPerPDU");
        $data->{'param'}{'snmp-oids-per-pdu'} = $oidsPerPDU;
    }

    my $result = $dd->retrieveSnmpOIDs('nsResSessMaxium');
    if( defined($result) and $result->{'nsResSessMaxium'} > 0 )
    {
        $devdetails->setCap('NetScreen::SessMax');

        my $param = {};
        my $max = $result->{'nsResSessMaxium'};

        $param->{'hrule-value-max'} = $max;
        $param->{'hrule-legend-max'} = 'Maximum Sessions';
        # upper limit of graph is 5% higher than max sessions
        $param->{'graph-upper-limit'} =
            sprintf('%e', 
                    ( $max * 5 / 100 ) + $max );
        
        $data->{'netScreenSessions'} = {
            'param' => $param,
        };        
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    my $data = $devdetails->data();


    { #Allocated Sessions

        my $ref = $data->{'netScreenSessions'};

        $cb->addSubtree( $devNode, "NetScreen_Sessions", $ref->{'param'}, 
            [ 'NetScreen::netscreen-sessions-stats' ] );

    }

    $cb->addTemplateApplication($devNode, 'NetScreen::netscreen-cpu-stats');
    $cb->addTemplateApplication($devNode, 'NetScreen::netscreen-memory-stats');
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
