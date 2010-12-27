#  Copyright (C) 2004 Marc Haber
#  Copyright (C) 2005 Stanislav Sinyagin
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
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

# $Id: AlliedTelesyn_PBC18.pm,v 1.1 2010-12-27 00:03:49 ivan Exp $
# Marc Haber <mh+torrus-devel@zugschlus.de>
# Redesigned by Stanislav Sinyagin

# Allied Telesyn 18-Slot Media Converter Chassis

package Torrus::DevDiscover::AlliedTelesyn_PBC18;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'AlliedTelesyn_PBC18'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     'ATMCCommon-MIB::mediaconverter'    => '1.3.6.1.4.1.207.1.12',
     'ATMCCommon-MIB::mcModuleName'      => '1.3.6.1.4.1.207.8.41.1.1.1.1.1.2',
     'ATMCCommon-MIB::mcModuleType'      => '1.3.6.1.4.1.207.8.41.1.1.1.1.1.3',
     'ATMCCommon-MIB::mcModuleState'     => '1.3.6.1.4.1.207.8.41.1.1.1.1.1.4',
     'ATMCCommon-MIB::mcModuleAportLinkState' =>
     '1.3.6.1.4.1.207.8.41.1.1.1.1.1.10',
     'ATMCCommon-MIB::mcModuleBportLinkState' =>
     '1.3.6.1.4.1.207.8.41.1.1.1.1.1.11',
     'ATMCCommon-MIB::mcModuleCportLinkState' =>
     '1.3.6.1.4.1.207.8.41.1.1.1.1.1.12',
     'ATMCCommon-MIB::mcModuleDportLinkState' =>
     '1.3.6.1.4.1.207.8.41.1.1.1.1.1.13',
     
     );


our %knownModuleTypes =
    (
     8 => 'AT-PB103/1 (1x100Base-TX, 1x100Base-FX Single-Mode Fibre SC, 15km)',
     );


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'ATMCCommon-MIB::mediaconverter',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
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
    my $session = $dd->session();
    
    # Modules table

    my $oid = $dd->oiddef('ATMCCommon-MIB::mcModuleType');
    
    my $table = $session->get_table( -baseoid => $oid );    
    if( not defined( $table ) )
    {
        return 0;
    }
    
    $devdetails->storeSnmpVars( $table );
    
    foreach my $INDEX ( $devdetails->getSnmpIndices($oid) )
    {
        my $moduleType = $devdetails->snmpVar( $oid . '.' . $INDEX );
        if( $moduleType == 0 )
        {
            next;
        }

        $data->{'PBC18'}{$INDEX} = {};
        if( defined( $knownModuleTypes{$moduleType} ) )
        {
            $data->{'PBC18'}{$INDEX}{'moduleDesc'} =
                $knownModuleTypes{$moduleType};
        }
        else
        {
            Warn('Unknown PBC18 module type: ' . $moduleType);
        }
    }

    foreach my $INDEX ( keys %{$data->{'PBC18'}} )
    {
        my $oids = [];
        foreach my $oidname ( 'ATMCCommon-MIB::mcModuleName',
                              'ATMCCommon-MIB::mcModuleState',
                              'ATMCCommon-MIB::mcModuleAportLinkState',
                              'ATMCCommon-MIB::mcModuleBportLinkState',
                              'ATMCCommon-MIB::mcModuleCportLinkState',
                              'ATMCCommon-MIB::mcModuleDportLinkState' )
        {
            push( @{$oids}, $dd->oiddef( $oidname ) . '.' . $INDEX );
        }
    
        my $result = $session->get_request( -varbindlist => $oids );
        if( $session->error_status() == 0 and defined( $result ) )
        {
            $devdetails->storeSnmpVars( $result );
        }
        else
        {
            Error('Error retrieving PBC18 module information');
            return 0;
        }
    }

    foreach my $INDEX ( keys %{$data->{'PBC18'}} )
    {
        if( $devdetails->snmpVar
            ( $dd->oiddef('ATMCCommon-MIB::mcModuleState') .'.'.$INDEX )
            != 1 )
        {
            delete $data->{'PBC18'}{$INDEX};
            next;
        }

        my $name = $devdetails->snmpVar
            ( $dd->oiddef('ATMCCommon-MIB::mcModuleName') .'.'.$INDEX );

        if( length( $name ) > 0 )
        {
            $data->{'PBC18'}{$INDEX}{'moduleName'} = $name;
        }

        foreach my $portName ('A', 'B', 'C', 'D')
        {
            my $oid = $dd->oiddef
                ('ATMCCommon-MIB::mcModule'.$portName.'portLinkState').
                '.'.$INDEX;
            
            my $portState = $devdetails->snmpVar ( $oid );
            if( $portState == 1 or $portState == 2 )
            {
                $data->{'PBC18'}{$INDEX}{'portAvailable'}{$portName} = $oid;
            }
        }        
    }

    return 1;
}           


our %portLineColors =
    (
     'A' => '##green',
     'B' => '##blue',
     'C' => '##red',
     'D' => '##gold'
     );


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my $data = $devdetails->data();

    my $param = {
        'data-file' => '%system-id%_pbc18_%pbc-module-index%.rrd',
        'collector-scale' => '-1,*,2,+',
        'graph-lower-limit' => 0,
        'graph-upper-limit' => 1,
        'rrd-cf' => 'MAX',
        'rrd-create-dstype' => 'GAUGE',
        'rrd-create-rra' =>
            'RRA:MAX:0:1:4032 RRA:MAX:0.17:6:2016 RRA:MAX:0.042:288:732',

            'has-overview-shortcuts' => 'yes',
            'overview-shortcuts' => 'links',
            'overview-subleave-name-links' => 'AllPorts',
            'overview-shortcut-text-links' => 'All modules',
            'overview-shortcut-title-links' => 'All converter modules',
            'overview-page-title-links' => 'All converter modules',            
        };

    $cb->addParams( $devNode, $param );
        
    foreach my $INDEX ( sort {$a<=>$b} keys %{$data->{'PBC18'}} )
    {
        my $param = { 'pbc-module-index' => $INDEX };
        
        if( defined( $data->{'PBC18'}{$INDEX}{'moduleDesc'} ) )
        {
            $param->{'legend'} =
                'Module type: ' . $data->{'PBC18'}{$INDEX}{'moduleDesc'};
        }

        if( defined( $data->{'PBC18'}{$INDEX}{'moduleName'} ) )
        {
            $param->{'comment'} =
                $data->{'PBC18'}{$INDEX}{'moduleName'};
        }
        
        my $modNode = $cb->addSubtree( $devNode, 'Module_' . $INDEX, $param );

        my $mgParam = {
            'ds-type'              => 'rrd-multigraph',
            'ds-names'             => '',
            'graph-lower-limit'    => '0',
            'precedence'           => '1000',
            'comment'              => 'Ports status',                
            'vertical-label'       => 'Status',                
        };
        
        my $n = 1;
        foreach my $portName
            ( sort keys %{$data->{'PBC18'}{$INDEX}{'portAvailable'}} )
        {
            if( $n > 1 )
            {
                $mgParam->{'ds-names'} .= ',';
            }

            my $dsname = 'port' . $portName;
            $mgParam->{'ds-names'} .= $dsname;

            $mgParam->{'graph-legend-' . $dsname} = 'Port ' . $portName;
            $mgParam->{'line-style-' . $dsname} = 'LINE2';
            $mgParam->{'line-color-' . $dsname} = $portLineColors{$portName};
            $mgParam->{'line-order-' . $dsname} = $n;
            $mgParam->{'ds-expr-' . $dsname} = '{Port_' . $portName . '}';
            
            my $param = {
                'rrd-ds' => 'Port' . $portName,
                'snmp-object' =>
                    $data->{'PBC18'}{$INDEX}{'portAvailable'}{$portName},
                };

            $cb->addLeaf( $modNode, 'Port_' . $portName, $param );
            $n++;
        }

        $cb->addLeaf( $modNode, 'AllPorts', $mgParam );        
    }
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
