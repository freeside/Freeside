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

# $Id: CiscoIOS_SAA.pm,v 1.1 2010-12-27 00:03:50 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Cisco IOS Service Assurance Agent
# TODO:
#   should really consider rtt-type and rtt-echo-protocol when applying
#   per-rtt templates
#
#   translate TOS bits into DSCP values

package Torrus::DevDiscover::CiscoIOS_SAA;

use strict;
use Socket qw(inet_ntoa);

use Torrus::Log;


$Torrus::DevDiscover::registry{'CiscoIOS_SAA'} = {
    'sequence'     => 510,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # CISCO-RTTMON-MIB
     'rttMonCtrlAdminTable'               => '1.3.6.1.4.1.9.9.42.1.2.1',
     'rttMonCtrlAdminOwner'               => '1.3.6.1.4.1.9.9.42.1.2.1.1.2',
     'rttMonCtrlAdminTag'                 => '1.3.6.1.4.1.9.9.42.1.2.1.1.3',
     'rttMonCtrlAdminRttType'             => '1.3.6.1.4.1.9.9.42.1.2.1.1.4',
     'rttMonCtrlAdminFrequency'           => '1.3.6.1.4.1.9.9.42.1.2.1.1.6',
     'rttMonCtrlAdminStatus'              => '1.3.6.1.4.1.9.9.42.1.2.1.1.9',
     'rttMonEchoAdminTable'               => '1.3.6.1.4.1.9.9.42.1.2.2',
     'rttMonEchoAdminProtocol'            => '1.3.6.1.4.1.9.9.42.1.2.2.1.1',
     'rttMonEchoAdminTargetAddress'       => '1.3.6.1.4.1.9.9.42.1.2.2.1.2',
     'rttMonEchoAdminPktDataRequestSize'  => '1.3.6.1.4.1.9.9.42.1.2.2.1.3',
     'rttMonEchoAdminTargetPort'          => '1.3.6.1.4.1.9.9.42.1.2.2.1.5',
     'rttMonEchoAdminTOS'                 => '1.3.6.1.4.1.9.9.42.1.2.2.1.9',
     'rttMonEchoAdminTargetAddressString' => '1.3.6.1.4.1.9.9.42.1.2.2.1.11',
     'rttMonEchoAdminNameServer'          => '1.3.6.1.4.1.9.9.42.1.2.2.1.12',
     'rttMonEchoAdminURL'                 => '1.3.6.1.4.1.9.9.42.1.2.2.1.15',
     'rttMonEchoAdminInterval'            => '1.3.6.1.4.1.9.9.42.1.2.2.1.17',
     'rttMonEchoAdminNumPackets'          => '1.3.6.1.4.1.9.9.42.1.2.2.1.18'
     );



our %adminInterpret =
    (
     'rttMonCtrlAdminOwner' => {
         'order'   => 10,
         'legend'  => 'Owner: %s;',
         'param'   => 'rtt-owner'
         },

     'rttMonCtrlAdminTag' => {
         'order'   => 20,
         'legend'  => 'Tag: %s;',
         'comment' => '%s: ',
         'param'   => 'rtt-tag'
         },

     'rttMonCtrlAdminRttType' => {
         'order'   => 30,
         'legend'  => 'Type: %s;',
         'translate' => \&translateRttType,
         'param'   => 'rtt-type'
         },

     'rttMonCtrlAdminFrequency' => {
         'order'   => 40,
         'legend'  => 'Frequency: %d seconds;',
         'param'   => 'rtt-frequency'
         },

     'rttMonEchoAdminProtocol' => {
         'order'   => 50,
         'legend'  => 'Protocol: %s;',
         'translate' => \&translateRttEchoProtocol,
         'param'   => 'rtt-echo-protocol'
         },

     'rttMonEchoAdminTargetAddress' => {
         'order'   => 60,
         'legend'  => 'Target: %s;',
         'comment' => 'Target=%s ',
         'translate' => \&translateRttTargetAddr,
         'param'   => 'rtt-echo-target-addr',
         'ignore-text' => '0.0.0.0'
         },

     'rttMonEchoAdminPktDataRequestSize' => {
         'order'   => 70,
         'legend'  => 'Packet size: %d octets;',
         'param'   => 'rtt-echo-request-size'
         },

     'rttMonEchoAdminTargetPort' => {
         'order'   => 80,
         'legend'  => 'Port: %d;',
         'param'   => 'rtt-echo-port',
         'ignore-numeric' => 0
         },

     'rttMonEchoAdminTOS' => {
         'order'   => 90,
         'legend'  => 'TOS: %d;',
         'comment' => 'TOS=%d ',
         'param'   => 'rtt-echo-tos',
         'ignore-numeric' => 0
         },

     'rttMonEchoAdminTargetAddressString' => {
         'order'   => 100,
         'legend'  => 'Address string: %s;',
         'param'   => 'rtt-echo-addr-string'
         },

     'rttMonEchoAdminNameServer' => {
         'order'   => 110,
         'legend'  => 'NameServer: %s;',
         'translate' => \&translateRttTargetAddr,
         'param'   => 'rtt-echo-name-server',
         'ignore-text' => '0.0.0.0'
         },

     'rttMonEchoAdminURL' => {
         'order'   => 120,
         'legend'  => 'URL: %s;',
         'param'   => 'rtt-echo-url'
         },

     'rttMonEchoAdminInterval' => {
         'order'   => 130,
         'legend'  => 'Interval: %d milliseconds;',
         'param'   => 'rtt-echo-interval',
         'ignore-numeric' => 0
         },

     'rttMonEchoAdminNumPackets' => {
         'order'   => 140,
         'legend'  => 'Packets: %d;',
         'param'   => 'rtt-echo-num-packets',
         'ignore-numeric' => 0
         }
     );



sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();

    if( $devdetails->isDevType('CiscoIOS') )
    {
        my $rttAdminTable =
            $session->get_table( -baseoid =>
                                 $dd->oiddef('rttMonCtrlAdminTable') );
        if( defined $rttAdminTable and scalar( %{$rttAdminTable} ) > 0 )
        {
            $devdetails->storeSnmpVars( $rttAdminTable );
            return 1;
        }
    }

    return 0;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    my $rttEchoAdminTable =
        $session->get_table( -baseoid =>
                             $dd->oiddef('rttMonEchoAdminTable') );
    if( defined $rttEchoAdminTable )
    {
        $devdetails->storeSnmpVars( $rttEchoAdminTable );
        undef $rttEchoAdminTable;
    }

    $data->{'rtt_entries'} = {};

    foreach my $rttIndex
        ( $devdetails->getSnmpIndices( $dd->oiddef('rttMonCtrlAdminOwner') ) )
    {
        # we're interested in Active agents only
        if( $devdetails->snmpVar($dd->oiddef('rttMonCtrlAdminStatus') .
                                 '.' . $rttIndex) != 1 )
        {
            next;
        }

        my $ref = {};
        $data->{'rtt_entries'}{$rttIndex} = $ref;
        $ref->{'param'} = {};

        my $comment = '';
        my $legend = '';

        foreach my $adminField
            ( sort {$adminInterpret{$a}{'order'} <=>
                        $adminInterpret{$b}{'order'}}
              keys %adminInterpret )
        {
            my $value = $devdetails->snmpVar( $dd->oiddef( $adminField ) .
                                              '.' . $rttIndex );
            if( defined( $value ) and length( $value ) > 0 )
            {
                my $intrp = $adminInterpret{$adminField};
                if( ref( $intrp->{'translate'} ) )
                {
                    $value = &{$intrp->{'translate'}}( $value );
                }

                if( ( defined( $intrp->{'ignore-numeric'} ) and
                      $value == $intrp->{'ignore-numeric'} )
                    or
                    ( defined( $intrp->{'ignore-text'} ) and
                      $value eq $intrp->{'ignore-text'} ) )
                {
                    next;
                }

                if( defined( $intrp->{'param'} ) )
                {
                    $ref->{'param'}{$intrp->{'param'}} = $value;
                }

                if( defined( $intrp->{'comment'} ) )
                {
                    $comment .= sprintf( $intrp->{'comment'}, $value );
                }

                if( defined( $intrp->{'legend'} ) )
                {
                    $legend .= sprintf( $intrp->{'legend'}, $value );
                }
            }
        }

        $ref->{'param'}{'rtt-index'} = $rttIndex;
        $ref->{'param'}{'comment'} = $comment;
        $ref->{'param'}{'legend'} = $legend;
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my $data = $devdetails->data();

    my $subtreeNode =
        $cb->addSubtree( $devNode, 'SAA', undef,
                         ['CiscoIOS_SAA::cisco-saa-subtree']);

    foreach my $rttIndex ( sort {$a<=>$b} keys %{$data->{'rtt_entries'}} )
    {
        my $subtreeName = 'rtt_' . $rttIndex;
        my $param = $data->{'rtt_entries'}{$rttIndex}{'param'};
        $param->{'precedence'} = sprintf('%d', 10000 - $rttIndex);

        # TODO: should really consider rtt-type and rtt-echo-protocol

        $cb->addSubtree( $subtreeNode, $subtreeName, $param,
                         ['CiscoIOS_SAA::cisco-rtt-echo-subtree']);
    }
}


our %rttType =
    (
     '1'  => 'echo',
     '2'  => 'pathEcho',
     '3'  => 'fileIO',
     '4'  => 'script',
     '5'  => 'udpEcho',
     '6'  => 'tcpConnect',
     '7'  => 'http',
     '8'  => 'dns',
     '9'  => 'jitter',
     '10' => 'dlsw',
     '11' => 'dhcp',
     '12' => 'ftp'
     );

sub translateRttType
{
    my $value = shift;
    return $rttType{$value};
}


our %rttEchoProtocol =
    (
     '1'   =>  'notApplicable',
     '2'   =>  'ipIcmpEcho',
     '3'   =>  'ipUdpEchoAppl',
     '4'   =>  'snaRUEcho',
     '5'   =>  'snaLU0EchoAppl',
     '6'   =>  'snaLU2EchoAppl',
     '7'   =>  'snaLU62Echo',
     '8'   =>  'snaLU62EchoAppl',
     '9'   =>  'appleTalkEcho',
     '10'  =>  'appleTalkEchoAppl',
     '11'  =>  'decNetEcho',
     '12'  =>  'decNetEchoAppl',
     '13'  =>  'ipxEcho',
     '14'  =>  'ipxEchoAppl',
     '15'  =>  'isoClnsEcho',
     '16'  =>  'isoClnsEchoAppl',
     '17'  =>  'vinesEcho',
     '18'  =>  'vinesEchoAppl',
     '19'  =>  'xnsEcho',
     '20'  =>  'xnsEchoAppl',
     '21'  =>  'apolloEcho',
     '22'  =>  'apolloEchoAppl',
     '23'  =>  'netbiosEchoAppl',
     '24'  =>  'ipTcpConn',
     '25'  =>  'httpAppl',
     '26'  =>  'dnsAppl',
     '27'  =>  'jitterAppl',
     '28'  =>  'dlswAppl',
     '29'  =>  'dhcpAppl',
     '30'  =>  'ftpAppl'
     );

sub translateRttEchoProtocol
{
    my $value = shift;
    return $rttEchoProtocol{$value};
}

sub translateRttTargetAddr
{
    my $value = shift;
    $value =~ s/^0x//;
    return inet_ntoa( pack( 'H8', $value ) );
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
