#  Copyright (C) 2008 Roman Hochuli
#  Copyright (C) 2010 Stanislav Sinyagin
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

# $Id: Foundry.pm,v 1.1 2010-12-27 00:03:48 ivan Exp $
# Roman Hochuli <roman@hochu.li>

# Common Foundry MIBs, supported by IronWare-Devices

package Torrus::DevDiscover::Foundry;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'Foundry'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # FOUNDRY-SN-ROOT-MIB
     'fdry'                              => '1.3.6.1.4.1.1991',
     
     # FOUNDRY-SN-AGENT-MIB
     'fdrySnChasSerNum'                  => '1.3.6.1.4.1.1991.1.1.1.1.2.0',
     'fdrySnChasGen'                     => '1.3.6.1.4.1.1991.1.1.1.1.13',
     'fdrySnChasIdNumber'                => '1.3.6.1.4.1.1991.1.1.1.1.17.0',
     'fdrySnChasArchitectureType'        => '1.3.6.1.4.1.1991.1.1.1.1.25.0',
     'fdrySnChasProductType'             => '1.3.6.1.4.1.1991.1.1.1.1.26.0',

     # FOUNDRY-SN-AGENT-MIB
     'fdrySnChasActualTemperature'       => '1.3.6.1.4.1.1991.1.1.1.1.18.0',
     'fdrySnChasWarningTemperature'      => '1.3.6.1.4.1.1991.1.1.1.1.19.0',
     'fdrySnChasShutdownTemperature'     => '1.3.6.1.4.1.1991.1.1.1.1.20.0',
     'fdrySnAgImgVer'                    => '1.3.6.1.4.1.1991.1.1.2.1.11',
     'fdrySnAgentTempTable'              => '1.3.6.1.4.1.1991.1.1.2.13.1',
     'fdrySnAgentTempSensorDescr'        => '1.3.6.1.4.1.1991.1.1.2.13.1.1.3',
     'fdrySnAgentTempValue'              => '1.3.6.1.4.1.1991.1.1.2.13.1.1.4',

     # FOUNDRY-SN-AGENT-MIB
     'fdrySnAgGblCpuUtilData'            => '1.3.6.1.4.1.1991.1.1.2.1.35',
     'fdrySnAgGblCpuUtil1SecAvg'         => '1.3.6.1.4.1.1991.1.1.2.1.50',
     'fdrySnAgGblCpuUtil5SecAvg'         => '1.3.6.1.4.1.1991.1.1.2.1.51',
     'fdrySnAgGblCpuUtil1MinAvg'         => '1.3.6.1.4.1.1991.1.1.2.1.52',
     'fdrySnAgentCpuUtilValue'           => '1.3.6.1.4.1.1991.1.1.2.11.1.1.4',
     'fdrySnAgentCpuUtil100thPercent'    => '1.3.6.1.4.1.1991.1.1.2.11.1.1.6',

     # FOUNDRY-SN-AGENT-MIB
     'fdrySnAgentBrdTbl'                 => '1.3.6.1.4.1.1991.1.1.2.2.1.1',
     'fdrySnAgentBrdMainBrdDescription'  => '1.3.6.1.4.1.1991.1.1.2.2.1.1.2',
     'fdrySnAgentBrdMainPortTotal'       => '1.3.6.1.4.1.1991.1.1.2.2.1.1.4',
     'fdrySnAgentBrdModuleStatus'        => '1.3.6.1.4.1.1991.1.1.2.2.1.1.12',
     # Not listed in FOUNDRY-SN-AGENT-MIB, but in release notes
     'fdrySnAgentBrdMemoryTotal'         => '1.3.6.1.4.1.1991.1.1.2.2.1.1.24',
     'fdrySnAgentBrdMemoryAvailable'     => '1.3.6.1.4.1.1991.1.1.2.2.1.1.25',
     );


# Not all interfaces are normally needed to monitor.
# You may override the interface filtering in devdiscover-siteconfig.pl:
# redefine $Torrus::DevDiscover::Foundry::interfaceFilter
# or define $Torrus::DevDiscover::Foundry::interfaceFilterOverlay

our $interfaceFilter;
our $interfaceFilterOverlay;
my %fdryInterfaceFilter;

if( not defined( $interfaceFilter ) )
{
    $interfaceFilter = \%fdryInterfaceFilter;
}

# Key is some unique symbolic name, does not mean anything
# ifType is the number to match the interface type
# ifDescr is the regexp to match the interface description
%fdryInterfaceFilter =
    (
     'lb' => {
         'ifType'  => 24,                    # softwareLoopback
     },
     
     'v' => {
         'ifType'  => 135,                   # l2vlan
     },

     'tnl' => {
         'ifType'  => 150,                   # mplsTunnel
     },
     );



my %productTypeAttr =
    (
     1 => {
         'desc' => 'BigIron MG8',
     },

     2 => {
         'desc' => 'NetIron 40G',
     },

     3 => {
         'desc' => 'NetIron IMR 640',
     },
     
     4 => {
         'desc' => 'NetIron RX 800',
     },
     
     5 => {
         'desc' => 'NetIron XMR 16000',
     },

     6 => {
         'desc' => 'NetIron RX 400',
     },
     
     7 => {
         'desc' => 'NetIron XMR 8000',
     },

     8 => {
         'desc' => 'NetIron RX 200',
     },

     9 => {
         'desc' => 'NetIron XMR 4000',
     },
     
     13 => {
         'desc' => 'NetIron MLX-32',
     },

     14 => {
         'desc' => 'NetIron XMR 32000',
     },

     15 => {
         'desc' => 'NetIron RX-32',
     },

     78 => {
         'desc' => 'FastIron',
     },

     0 => {
         'desc' => 'device',
     },
     );  


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;
    my $retval = 0;

    if( $dd->oidBaseMatch
        ( 'fdry', $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
    {
        $retval = 1;

        &Torrus::DevDiscover::RFC2863_IF_MIB::addInterfaceFilter
            ($devdetails, $interfaceFilter);

        if( defined( $interfaceFilterOverlay ) )
        {
            &Torrus::DevDiscover::RFC2863_IF_MIB::addInterfaceFilter
                ($devdetails, $interfaceFilterOverlay);
        }

        $devdetails->setCap('interfaceIndexingPersistent');

    }
    
    return $retval;
}



sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    # NOTE: Comments and Serial number of device
    
    my $chassis = $dd->retrieveSnmpOIDs( 'fdrySnChasSerNum',
                                         'fdrySnChasIdNumber',
                                         'fdrySnChasArchitectureType',
                                         'fdrySnChasProductType' );
    
    Debug('fdrySnChasSerNum=' . $chassis->{'fdrySnChasSerNum'});
    Debug('fdrySnChasIdNumber=' . $chassis->{'fdrySnChasIdNumber'});
    Debug('fdrySnChasArchitectureType=' .
          $chassis->{'fdrySnChasArchitectureType'});
    Debug('fdrySnChasProductType=' . $chassis->{'fdrySnChasProductType'});
    
    my $productType = 0;

    if( defined( $chassis ) and
        defined( $productTypeAttr{$chassis->{'fdrySnChasProductType'}} ) )
    {
        $productType = $chassis->{'fdrySnChasProductType'};
    }

    my $deviceComment = 'Brocade ' . $productTypeAttr{$productType}{'desc'};
        
    if( defined( $chassis ) )
    {
        if( defined( $chassis->{'fdrySnChasSerNum'} ) )
        {
            $deviceComment .= ', Chassis S/N: ' .
                $chassis->{'fdrySnChasSerNum'};
        }
        
        if( defined( $chassis->{'fdrySnChasIdNumber'} ) and
            $chassis->{'fdrySnChasIdNumber'} ne '' )
        {
            $deviceComment .= ', Chassis ID: ' .
                $chassis->{'fdrySnChasIdNumber'};
        }
    }

    $data->{'param'}{'comment'} = $deviceComment;

    
    my $chasTemp = $dd->retrieveSnmpOIDs( 'fdrySnChasActualTemperature',
                                          'fdrySnChasWarningTemperature',
                                          'fdrySnChasShutdownTemperature');

    if( defined($chasTemp) and
        defined($chasTemp->{'fdrySnChasActualTemperature'}) )
    {
        $devdetails->setCap('snChasActualTemperature');

        $data->{'fdryChasTemp'}{'warning'} =
            $chasTemp->{'fdrySnChasWarningTemperature'};
        $data->{'fdryChasTemp'}{'shutdown'} =
            $chasTemp->{'fdrySnChasShutdownTemperature'};        
    }
       
    if( $dd->checkSnmpTable('fdrySnAgentBrdTbl') )
    {
        $devdetails->setCap('fdryBoardStats'); 
        $data->{'fdryBoard'} = {};

        # get only the modules with
        # snAgentBrdModuleStatus = moduleRunning(10)
        {
            my $base = $dd->oiddef('fdrySnAgentBrdModuleStatus');
            my $table = $session->get_table( -baseoid => $base );        
            my $prefixLen = length( $base ) + 1;
            
            while( my( $oid, $status ) = each %{$table} )
            {
                if( $status == 10 )
                {
                    my $brdIndex = substr( $oid, $prefixLen );
                    $data->{'fdryBoard'}{$brdIndex}{'moduleRunning'} = 1;
                }
            }
        }
        
        # get module descriptions
        {
            my $oid = $dd->oiddef('fdrySnAgentBrdMainBrdDescription');
            my $table = $session->get_table( -baseoid => $oid );        
            my $prefixLen = length( $oid ) + 1;
            
            while( my( $oid, $descr ) = each %{$table} )
            {
                if( length($descr) > 0 )
                {
                    my $brdIndex = substr( $oid, $prefixLen );
                    
                    if( $data->{'fdryBoard'}{$brdIndex}{'moduleRunning'} )
                    {
                        $data->{'fdryBoard'}{$brdIndex}{'description'} =
                            $descr;
                    }
                }
            }
        }

        # Non-chassis Foundry products set the description to "Invalid Module"
        if( scalar(keys %{$data->{'fdryBoard'}}) == 1 and
            $data->{'fdryBoard'}{1}{'moduleRunning'} )
        {
            $data->{'fdryBoard'}{1}{'description'} = 'Management';
        }

        # check if memory statistics are available
        {
            my $base = $dd->oiddef('fdrySnAgentBrdMemoryTotal');
            my $table = $session->get_table( -baseoid => $base );        
            my $prefixLen = length( $base ) + 1;
            
            while( my( $oid, $memory ) = each %{$table} )
            {
                if( $memory > 0 )
                {
                    my $brdIndex = substr( $oid, $prefixLen );
                    
                    if( $data->{'fdryBoard'}{$brdIndex}{'moduleRunning'} )
                    {
                        $data->{'fdryBoard'}{$brdIndex}{'memory'} = 1;
                    }
                }
            }
        }

        # check if CPU stats are available
        # FOUNDRY-SN-AGENT-MIB::snAgentCpuUtilValue.1.1.1 = Gauge32: 1
        # FOUNDRY-SN-AGENT-MIB::snAgentCpuUtilValue.1.1.5 = Gauge32: 1
        # FOUNDRY-SN-AGENT-MIB::snAgentCpuUtilValue.1.1.60 = Gauge32: 1
        # FOUNDRY-SN-AGENT-MIB::snAgentCpuUtilValue.1.1.300 = Gauge32: 1
        {
            my $base = $dd->oiddef('fdrySnAgentCpuUtilValue');
            my $table = $session->get_table( -baseoid => $base );
            my $prefixLen = length( $base ) + 1;
                
            while( my( $oid, $val ) = each %{$table} )
            {
                my $brdIndex = substr( $oid, $prefixLen );
                $brdIndex =~ s/\.(.+)$//o;
                if( $1 eq '1.1' and
                    $data->{'fdryBoard'}{$brdIndex}{'moduleRunning'} )
                {
                    $data->{'fdryBoard'}{$brdIndex}{'cpu'} = 1;
                }
            }
        }

        # snAgentCpuUtil100thPercent: supported on NetIron XMR and NetIron
        # MLX devices running software release 03.9.00 and later, FGS release
        # 04.3.01 and later, and FSX 04.3.00 and later.
        # snAgentCpuUtilValue is deprecated in these releases
        {
            my $base = $dd->oiddef('fdrySnAgentCpuUtil100thPercent');
            my $table = $session->get_table( -baseoid => $base );
            my $prefixLen = length( $base ) + 1;
                
            while( my( $oid, $val ) = each %{$table} )
            {
                my $brdIndex = substr( $oid, $prefixLen );
                $brdIndex =~ s/\.(.+)$//o;
                if( $1 eq '1.1' and
                    $data->{'fdryBoard'}{$brdIndex}{'moduleRunning'} )
                {
                    $data->{'fdryBoard'}{$brdIndex}{'cpu-new'} = 1;
                }
            }
        }        
        
        # check if temperature stats are available
        # exclude the sensors which show zero
        {
            my $base = $dd->oiddef('fdrySnAgentTempSensorDescr');
            my $table = $session->get_table( -baseoid => $base );        
            my $prefixLen = length( $base ) + 1;

            my $baseVal = $dd->oiddef('fdrySnAgentTempValue');
            my $values = $session->get_table( -baseoid => $baseVal );
            
            while( my( $oid, $descr ) = each %{$table} )
            {
                my $index = substr( $oid, $prefixLen );
                my ($brdIndex, $sensor) = split(/\./, $index);
                
                if( $data->{'fdryBoard'}{$brdIndex}{'moduleRunning'} and
                    $values->{$baseVal . '.' . $index} > 0 )
                {
                    $data->{'fdryBoard'}{$brdIndex}{'temperature'}{$sensor} =
                        $descr;
                    $devdetails->setCap('fdryBoardTemperature'); 
                }
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

    # Chassis Temperature Sensors
    if( $devdetails->hasCap('snChasActualTemperature') and not
        $devdetails->hasCap('fdryBoardTemperature') )
    {
        my $param = {
            'fdry-chastemp-warning' => $data->{'fdryChasTemp'}{'warning'}/2,
            'fdry-chastemp-shutdown' => $data->{'fdryChasTemp'}{'shutdown'}/2,
        };
                         
        my $templates = [ 'Foundry::fdry-chass-temperature' ];

        $cb->addLeaf( $devNode, 'Chassis_Temperature',
                      $param, $templates );
    }
    
    # Board Stats
    if( $devdetails->hasCap('fdryBoardStats') )
    {
        my $brdNode = $devNode;
        if( scalar(keys %{$data->{'fdryBoard'}}) > 1 )
        {
            my $param = {
                'node-display-name' => 'Linecard Statistics',
                'comment' => 'CPU, Memory, and Temperature information',
            };
            
            $brdNode =
                $cb->addSubtree( $devNode, 'Linecard_Statistics', $param );
        }
       
        $cb->addTemplateApplication( $brdNode,
                                     'Foundry::fdry-board-overview' );
        
            
        foreach my $brdIndex ( sort {$a <=> $b} keys %{$data->{'fdryBoard'}} )
        {
            my $descr = $data->{'fdryBoard'}{$brdIndex}{'description'};
            my $param = {
                'comment'  => $descr,
                'fdry-board-index' => $brdIndex,
                'fdry-board-descr' => $descr,
                'nodeid' => 'module//%nodeid-device%//' . $brdIndex,
            };
            
            my $linecardNode =
                $cb->addSubtree( $brdNode, 'Linecard_' . $brdIndex,
                                 $param,
                                 [ 'Foundry::fdry-board-subtree' ]);
            
            if( $data->{'fdryBoard'}{$brdIndex}{'memory'} )
            {
                $cb->addSubtree( $linecardNode, 'Memory_Statistics', {},
                                 [ 'Foundry::fdry-board-memstats' ]);
            }
            

            my $cpuOid;            
            if( $data->{'fdryBoard'}{$brdIndex}{'cpu-new'} )
            {
                $cpuOid = '$fdrySnAgentCpuUtil100thPercent';
            }
            elsif( $data->{'fdryBoard'}{$brdIndex}{'cpu'} )                
            {
                $cpuOid = '$fdrySnAgentCpuUtilValue';
            }

            if( defined( $cpuOid ) )
            {
                
                $cb->addSubtree
                    ( $linecardNode, 'CPU_Statistics',
                      {
                          'fdry-cpu-base' => $cpuOid,
                          'nodeid' => 'cpu//%nodeid-device%//' . $brdIndex,
                      },
                      [ 'Foundry::fdry-board-cpustats' ]);
            }
            
            if( defined( $data->{'fdryBoard'}{$brdIndex}{'temperature'} ) )
            {
                my $tempNode =
                    $cb->addSubtree( $linecardNode, 'Temperature_Statistics',
                                     {}, ['Foundry::fdry-board-tempstats']);

                # Build a multi-graph for all sensors
                
                my @colors =
                    ('##one', '##two', '##three', '##four', '##five',
                     '##six', '##seven', '##eight', '##nine', '##ten');

                my $mgParam = {
                    'comment' => 'Board temperature sensors combined',
                    'ds-type' => 'rrd-multigraph',
                    'vertical-label' => 'Degrees Celcius',
                    'nodeid' => 'temp//%nodeid-device%//' . $brdIndex,
                };

                my @sensors;
                
                foreach my $sensor
                    ( sort {$a <=> $b}
                      keys %{$data->{'fdryBoard'}{$brdIndex}{'temperature'}} )
                {
                    my $leafName = 'sensor_' . $sensor;
                    
                    my $descr = $data->{'fdryBoard'}{$brdIndex}{
                        'temperature'}{$sensor};

                    my $short = 'Temperature sensor ' . $sensor;
                    
                    my $param = {
                        'comment'            => $descr,
                        'precedence'         => 1000 - $sensor,
                        'sensor-index'       => $sensor,
                        'sensor-short'       => $short,
                        'sensor-description' => $descr,                        
                    };
                    
                    $cb->addLeaf
                        ( $tempNode, $leafName, $param,
                          ['Foundry::fdry-board-temp-sensor-halfcelsius'] );
                    
                    push(@sensors, $leafName);
                    
                    $mgParam->{'ds-expr-' . $leafName} =
                        '{' . $leafName . '}';
                    $mgParam->{'graph-legend-' . $leafName} = $short;
                    $mgParam->{'line-style-' . $leafName} = 'LINE2';

                    my $color = shift @colors;
                    if( not defined( $color ) )
                    {
                        Error('Too many sensors on one Foundry board');
                        $color = '##black';
                    }                    
                    $mgParam->{'line-color-' . $leafName} = $color;
                    
                    $mgParam->{'line-order-' . $leafName} = $sensor;
                }

                $mgParam->{'ds-names'} = join(',', @sensors);

                $cb->addLeaf( $tempNode, 'Temperature_Overview', $mgParam );
            }
        }
    }
}



1;
