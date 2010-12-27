#  Copyright (C) 2005  Stanislav Sinyagin
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

# $Id: RFC2011_IP_MIB.pm,v 1.1 2010-12-27 00:03:56 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Discovery module for IP-MIB (RFC 2011)
# This module does not generate any XML, but provides information
# for other discovery modules. For the sake of discovery time and traffic,
# it is not implicitly executed during the normal discovery process.

package Torrus::DevDiscover::RFC2011_IP_MIB;

use strict;
use Torrus::Log;


our %oiddef =
    (
     # IP-MIB
     'ipNetToMediaTable'       => '1.3.6.1.2.1.4.22',
     'ipNetToMediaPhysAddress' => '1.3.6.1.2.1.4.22.1.2',
     );




sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();
    my $session = $dd->session();

    my $table = $session->get_table( -baseoid =>
                                     $dd->oiddef('ipNetToMediaPhysAddress'));
    
    if( not defined( $table ) or scalar( %{$table} ) == 0 )
    {
        return 0;
    }
    
    $devdetails->storeSnmpVars( $table );

    foreach my $INDEX
        ( $devdetails->
          getSnmpIndices( $dd->oiddef('ipNetToMediaPhysAddress') ) )
    {
        my( $ifIndex, @ipAddrOctets ) = split( '\.', $INDEX );
        my $ipAddr = join('.', @ipAddrOctets);

        my $interface = $data->{'interfaces'}{$ifIndex};
        next if not defined( $interface );

        my $phyAddr =
            $devdetails->snmpVar($dd->oiddef('ipNetToMediaPhysAddress') .
                                 '.' . $INDEX);

        $interface->{'ipNetToMedia'}{$ipAddr} = $phyAddr;
        $interface->{'mediaToIpNet'}{$phyAddr} = $ipAddr;

        # Cisco routers assign ARP to subinterfaces, but MAC accounting
        # to main interfaces. Let them search in a global table
        $data->{'ipNetToMedia'}{$ipAddr} = $phyAddr;
        $data->{'mediaToIpNet'}{$phyAddr} = $ipAddr;
    }
                            
    return 1;
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
