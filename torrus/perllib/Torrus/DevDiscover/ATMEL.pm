#  Copyright (C) 2004  Scott Brooks
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

# Scott Brooks <sbrooks@binary-solutions.net>

# ATMEL based access points/bridges

package Torrus::DevDiscover::ATMEL;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'ATMEL'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # Check to see if we can get the list of running WSS ports
     'sysDeviceInfo'           => '1.3.6.1.4.1.410.1.1.1.5.0',
     'bridgeOperationalMode'   => '1.3.6.1.4.1.410.1.1.4.1.0',
     'operAccessPointName'     => '1.3.6.1.4.1.410.1.2.1.10.0',
     'bridgeRemoteBridgeBSSID' => '1.3.6.1.4.1.410.1.1.4.2.0'
     );


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->checkSnmpOID('sysDeviceInfo') )
    {
        return 0;
    }
       
    return 1;
}

sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();

    my $info = $dd->retrieveSnmpOIDs('sysDeviceInfo',
                                     'operAccessPointName',
                                     'bridgeOperationalMode',
                                     'bridgeRemoteBridgeBSSID',
                                     );

    my $deviceInfo = substr($info->{'sysDeviceInfo'},2);    
    my $bridgeName = $info->{'operAccessPointName'};
    
    #Get rid of all the nulls returned.
    $bridgeName =~ s/\000//g;
    
    $data->{'param'}{'comment'} = $bridgeName;

    my $bridgeMode = $info->{'bridgeOperationalMode'};

    my $remoteMac = substr($info->{'bridgeRemoteBridgeBSSID'},2);
    
    $remoteMac =~ s/(\w\w)/$1-/g;
    $remoteMac = substr($remoteMac,0,-1);

    my $bridge=0;

    my ($version,$macaddr,$reserved,$regdomain,$producttype,$oemname,$oemid,
        $productname,$hardwarerev) = unpack("LH12SLLA32LA32L",
                                            pack("H*", $deviceInfo));
    
    $macaddr =~ s/(\w\w)/$1-/g;
    $macaddr = substr($macaddr,0,-1);
    
    $data->{'param'}{'comment'} = $bridgeName;
    
    if ($productname =~ m/airPoint/)
    {
        #we have an access point
        if ($bridgeMode == 3)
        {
            #we have an access point in client bridge mode.
            $bridge=1;
        }
    }
    else
    {
        #we have a bridge
        $bridge=1;
    }
    if (!$bridge)
    {
        $devdetails->setCap('ATMEL::accessPoint');
        my $legend =
            "AP: " . $bridgeName .";" .
            "Mac: " . $macaddr.";";
        $data->{'param'}{'legend'} .= $legend;

    }
    else
    {
        my $legend =
            "Bridge: " . $bridgeName .";" .
            "Mac: " . $macaddr.";";
        $data->{'param'}{'legend'} .= $legend;

        $data->{'param'}{'legend'} .= "AP Mac: " . $remoteMac . ";";
    }
    #disable SNMP uptime check
    $data->{'param'}{'snmp-check-sysuptime'} = 'no';
    
    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my @templates = ('ATMEL::atmel-device-subtree');

    if( $devdetails->hasCap('ATMEL::accessPoint') )
    {
        push (@templates, 'ATMEL::atmel-accesspoint-stats');
    }
    else
    {
        push (@templates, 'ATMEL::atmel-client-stats');
    }

    foreach my $tmpl ( @templates )
    {
        $cb->addTemplateApplication( $devNode, $tmpl );
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
