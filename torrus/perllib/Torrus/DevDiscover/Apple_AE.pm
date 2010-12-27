#
#  Copyright (C) 2007  Jon Nistor
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

# $Id: Apple_AE.pm,v 1.1 2010-12-27 00:03:55 ivan Exp $
# Jon Nistor <nistor at snickers.org>

# Apple Airport Extreme Discovery Module
#
# NOTE: Options for this module:
#       Apple_AE::disable-clients

package Torrus::DevDiscover::Apple_AE;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'Apple_AE'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
};


our %oiddef =
    (
     # Apple Airport Extreme
     'airportObject'        => '1.3.6.1.4.1.63.501',
     'baseStation3'         => '1.3.6.1.4.1.63.501.3',

     # Airport Information
     'sysConfName'            => '1.3.6.1.4.1.63.501.3.1.1.0',
     'sysConfContact'         => '1.3.6.1.4.1.63.501.3.1.2.0',
     'sysConfLocation'        => '1.3.6.1.4.1.63.501.3.1.3.0',
     'sysConfFirmwareVersion' => '1.3.6.1.4.1.63.501.3.1.5.0',

     'wirelessNumber'         => '1.3.6.1.4.1.63.501.3.2.1.0',
     'wirelessPhysAddress'    => '1.3.6.1.4.1.63.501.3.2.2.1.1'
    );


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    # PROG: Standard sysObject does not work on Airport devices
    #       So we will match on the specific OID
    if( not $dd->checkSnmpOID('sysConfName') )
    {
        return 0;
    }

    $devdetails->setCap('interfaceIndexingPersistent');

    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    # NOTE: Comments and Serial number of device
    my $chassisInfo =
        $dd->retrieveSnmpOIDs( 'sysConfName', 'sysConfLocation',
                               'sysConfFirmwareVersion' );

    if( defined( $chassisInfo ) )
    {
        if( not $chassisInfo->{'sysConfLocation'} )
        {
            $chassisInfo->{'sysConfLocation'} = "unknown";
        }

        $data->{'param'}{'comment'} = "Apple Airport Extreme, " .
            "Fw#: " . $chassisInfo->{'sysConfFirmwareVersion'} . ", " .
            $chassisInfo->{'sysConfName'} . " located at " .
            $chassisInfo->{'sysConfLocation'};
    } else {
        $data->{'param'}{'comment'} = "Apple Airport Extreme";
    }


    # PROG: Find wireless clients
    if( $devdetails->param('Apple_AE::disable-clients') ne 'yes' )
    {
        my $numWireless = $dd->retrieveSnmpOIDs('wirelessNumber');

        my $tableClients =
            $session->get_table( -baseoid =>
                                 $dd->oiddef('wirelessPhysAddress') );
        $devdetails->storeSnmpVars( $tableClients );

        if( $tableClients && ($numWireless->{'wirelessNumber'} > 0) )
        {
            # PROG: setCap that we actually have clients ...
            $devdetails->setCap('AE_clients');

            foreach my $wClient ( $devdetails->getSnmpIndices
                                  ($dd->oiddef('wirelessPhysAddress')) )
            {
                my $wMAC = $devdetails->snmpVar(
                    $dd->oiddef('wirelessPhysAddress') . "." . $wClient);

                # Construct data
                $data->{'Apple_AE'}{'wClients'}{$wClient} = undef;
                $data->{'Apple_AE'}{'wClients'}{$wClient}{'wMAC'} = $wMAC;

                Debug("Apple_AE::  Client $wMAC / $wClient");
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


    # Wireless Client information
    if( $devdetails->hasCap('AE_clients') )
    {
        my $nodeTop =
            $cb->addSubtree( $devNode, 'Wireless_Clients', undef,
                             [ 'Apple_AE::ae-wireless-clients-subtree'] );

        foreach my $wClient ( keys %{$data->{'Apple_AE'}{'wClients'}} )
        {
            my $airport = $data->{'Apple_AE'}{'wClients'}{$wClient};
            my $wMAC    = $airport->{'wMAC'};
            my $wMACfix = $wMAC;
            $wMACfix =~ s/:/_/g;

            my $nodeWireless =
                $cb->addSubtree( $nodeTop, $wMACfix,
                                 { 'wireless-mac'    => $wMAC,
                                   'wireless-macFix' => $wMACfix,
                                   'wireless-macOid' => $wClient },
                                 [ 'Apple_AE::ae-wireless-clients-leaf' ] );
        }
    }

    # PROG: Adding global statistics
    $cb->addTemplateApplication( $devNode, 'Apple_AE::ae-global-stats');
}


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
