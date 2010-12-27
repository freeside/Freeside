#
#  Discovery module for Symmetricom
#
#  Copyright (C) 2007 Jon Nistor
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

# $Id: Symmetricom.pm,v 1.1 2010-12-27 00:03:46 ivan Exp $
# Jon Nistor <nistor at snickers dot org>
#


# Symmetricom
package Torrus::DevDiscover::Symmetricom;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'Symmetricom'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

our %oiddef = (
     # SYMM-SMI
     'syncServer'           => '1.3.6.1.4.1.9070.1.2.3.1.5',
     'sysDescr'             => '1.3.6.1.2.1.1.1.0',
     'ntpSysSystem'         => '1.3.6.1.4.1.9070.1.2.3.1.5.1.1.14.0',
     'etcSerialNbr'         => '1.3.6.1.4.1.9070.1.2.3.1.5.1.6.2.0',
     'etcModel'             => '1.3.6.1.4.1.9070.1.2.3.1.5.1.6.3.0',
     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'syncServer',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
    {
        return 0;
    }
    
    $devdetails->setCap('interfaceIndexingPersistent');
    $devdetails->setDevType('UcdSnmp'); # Force load Ucd

    return 1;
}

sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    # SNMP: Get the system info and display it in the comment
    my $ntpComment = $dd->retrieveSnmpOIDs
        ( 'sysDescr', 'ntpSysSystem', 'etcSerialNbr', 'etcModel' );

    $data->{'ntp'} = $ntpComment;

    $data->{'param'}{'comment'} =
        $ntpComment->{'ntpSysSystem'} . " " . $ntpComment->{'etcModel'} . 
        ", Hw Serial#: " . $ntpComment->{'etcSerialNbr'};
  
    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    my $data = $devdetails->data();

    $cb->addTemplateApplication($devNode, 'Symmetricom::ntp-stats');
}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
