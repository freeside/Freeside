#
#  Copyright (C) 2009  Jon Nistor
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

# $Id: Arista.pm,v 1.1 2010-12-27 00:03:49 ivan Exp $
# Jon Nistor <nistor at snickers.org>

# Force10 Networks Real Time Operating System Software
#
# NOTE: Arista::x

package Torrus::DevDiscover::Arista;

use strict;
use Torrus::Log;

$Torrus::DevDiscover::registry{'Arista'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     'sysDescr'		=> '1.3.6.1.2.1.1.1.0',
     # Arista
     'aristaProducts'	=> '1.3.6.1.4.1.30065.1'

     );


# Not all interfaces are normally needed to monitor.
# You may override the interface filtering in devdiscover-siteconfig.pl:
# redefine $Torrus::DevDiscover::Arista::interfaceFilter
# or define $Torrus::DevDiscover::Arista::interfaceFilterOverlay

our $interfaceFilter;
our $interfaceFilterOverlay;
my %aristaInterfaceFilter;

if( not defined( $interfaceFilter ) )
{
    $interfaceFilter = \%aristaInterfaceFilter;
}


# Key is some unique symbolic name, does not mean anything
#  ifType is the number to match the interface type
# ifDescr is the regexp to match the interface description
%aristaInterfaceFilter =
    (
     'other' => {
         'ifType'  => 1,                     # other
     },
     'lag'      => {
         'ifType'  => 161,                   # ieee 802.3ad LAG groups
                                             # added due to index too high
     },
     'loopback' => {
         'ifType'  => 24,                    # softwareLoopback
     },
     'vlan' => {
         'ifType'  => 136,                   # vlan
                                             # added due to index too high
     },

    );


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'aristaProducts',
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

    my $session = $dd->session();
    my $data = $devdetails->data();

    # PROG: Add comment for sysDescr
    my $desc	= $dd->retrieveSnmpOIDs('sysDescr');
    $data->{'param'}{'comment'} = $desc->{'sysDescr'};
    
    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    my $data = $devdetails->data();

}


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
