#
#  Discovery module for Alteon devices
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

# $Id: Alteon.pm,v 1.1 2010-12-27 00:03:55 ivan Exp $
# Jon Nistor <nistor at snickers dot org>
#


package Torrus::DevDiscover::Alteon;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'Alteon'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

# pmodule-dependend OIDs are presented for module #1 only.
# currently devices with more than one module do not exist

our %oiddef =
    (
     # ALTEON-PRIVATE-MIBS
     'alteonOID'                 => '1.3.6.1.4.1.1872.1',
     'hwPartNumber'              => '1.3.6.1.4.1.1872.2.1.1.1.0',
     'hwRevision'                => '1.3.6.1.4.1.1872.2.1.1.2.0',
     'agSoftwareVersion'         => '1.3.6.1.4.1.1872.2.1.2.1.7.0',
     'agEnabledSwFeatures'       => '1.3.6.1.4.1.1872.2.1.2.1.25.0',
     'slbCurCfgRealServerName'   => '1.3.6.1.4.1.1872.2.1.5.2.1.12',
     'slbNewCfgRealServerName'   => '1.3.6.1.4.1.1872.2.1.5.3.1.13',
     'slbCurCfgGroupName'        => '1.3.6.1.4.1.1872.2.1.5.10.1.7',
     'slbNewCfgGroupName'        => '1.3.6.1.4.1.1872.2.1.5.11.1.10',
     'slbStatPortMaintPortIndex' => '1.3.6.1.4.1.1872.2.1.8.2.1.1.1',
     'slbStatVServerIndex'       => '1.3.6.1.4.1.1872.2.1.8.2.7.1.3',
     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'alteonOID',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
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

    # Get the system info and display it in the comment
    my $alteonInfo = $dd->retrieveSnmpOIDs
        ( 'hwPartNumber', 'hwRevision', 'agSoftwareVersion',
          'agEnabledSwFeatures', 'sysDescr' );

    $data->{'param'}{'comment'} =
        $alteonInfo->{'sysDescr'} . ", Hw Serial#: " .
        $alteonInfo->{'hwPartNumber'} . ", Hw Revision: " .
        $alteonInfo->{'hwRevision'} .  ", " .
        $alteonInfo->{'agEnabledSwFeatures'} . ", Version: " .
        $alteonInfo->{'agSoftwareVersion'};

    # PROG: Discover slbStatVServerIndex (Virtual Server index)
    my $virtTable = $session->get_table ( -baseoid =>
                                          $dd->oiddef('slbStatVServerIndex') );
    $devdetails->storeSnmpVars( $virtTable ); 
    foreach my $virtIndex
        ( $devdetails->getSnmpIndices( $dd->oiddef('slbStatVServerIndex') ) )
    {
        Debug("Alteon::vserver  Found index $virtIndex");
        $data->{'VSERVER'}{$virtIndex} = 1;
    }

    # PROG: SLB Port Maintenance Statistics Table
    my $maintTable =
        $session->get_table ( -baseoid =>
                              $dd->oiddef('slbStatPortMaintPortIndex') );
    $devdetails->storeSnmpVars( $maintTable );
    
    foreach my $mIndex
        ( $devdetails->getSnmpIndices
          ( $dd->oiddef('slbStatPortMaintPortIndex') ) )
    {
        Debug("Alteon::maintTable  Index: $mIndex");
        $data->{'MAINT'}{$mIndex} = 1;
    }
    
    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    my $data = $devdetails->data();

    $cb->addTemplateApplication($devNode, 'Alteon::alteon-cpu');
    $cb->addTemplateApplication($devNode, 'Alteon::alteon-mem');
    $cb->addTemplateApplication($devNode, 'Alteon::alteon-packets');
    $cb->addTemplateApplication($devNode, 'Alteon::alteon-sensor');

    # PROG: Virtual Server information
    my $virtNode =
        $cb->addSubtree( $devNode, 'VirtualServer_Stats',
                         { 'comment' => 'Stats per Virtual Server' },
                         [ 'Alteon::alteon-vserver-subtree'] );

    foreach my $virtIndex ( sort {$a <=> $b } keys %{$data->{'VSERVER'}} )
    {
        $cb->addSubtree( $virtNode, 'VirtualHost_' . $virtIndex,
                         { 'alteon-vserver-index' => $virtIndex },
                         [ 'Alteon::alteon-vserver'] ); 
    } 

    # PROG: SLB Port Maintenance Statistics Table
    my $maintNode =
        $cb->addSubtree( $devNode, 'Port_Maintenance_Stats',
                         { 'comment' => 'SLB port maintenance statistics' },
                         [ 'Alteon::alteon-maint-subtree'] );
    
    foreach my $mIndex ( sort {$a <=> $b } keys %{$data->{'MAINT'}} )
    {
        $cb->addSubtree( $maintNode, 'Port_' . $mIndex,
                         { 'alteon-maint-index' => $mIndex },
                         [ 'Alteon::alteon-maint'] ); 
    }

}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
