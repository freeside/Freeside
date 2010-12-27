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

# $Id: CiscoGeneric.pm,v 1.1 2010-12-27 00:03:48 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Common Cisco MIBs, supported by many IOS and CatOS devices

package Torrus::DevDiscover::CiscoGeneric;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'CiscoGeneric'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # CISCO-SMI
     'cisco'                             => '1.3.6.1.4.1.9',

     # CISCO-ENVMON-MIB
     'ciscoEnvMonTemperatureStatusDescr' => '1.3.6.1.4.1.9.9.13.1.3.1.2',
     'ciscoEnvMonTemperatureStatusValue' => '1.3.6.1.4.1.9.9.13.1.3.1.3',
     'ciscoEnvMonTemperatureThreshold'   => '1.3.6.1.4.1.9.9.13.1.3.1.4',
     'ciscoEnvMonTemperatureStatusState' => '1.3.6.1.4.1.9.9.13.1.3.1.6',
     'ciscoEnvMonSupplyState'            => '1.3.6.1.4.1.9.9.13.1.5.1.3',

     # CISCO-ENHANCED-MEMPOOL-MIB
     'cempMemPoolName'                   => '1.3.6.1.4.1.9.9.221.1.1.1.1.3',
     
     # CISCO-MEMORY-POOL-MIB
     'ciscoMemoryPoolName'               => '1.3.6.1.4.1.9.9.48.1.1.1.2',

     # CISCO-PROCESS-MIB
     'cpmCPUTotalTable'                  => '1.3.6.1.4.1.9.9.109.1.1.1.1',
     'cpmCPUTotalPhysicalIndex'          => '1.3.6.1.4.1.9.9.109.1.1.1.1.2',
     'cpmCPUTotal1minRev'                => '1.3.6.1.4.1.9.9.109.1.1.1.1.7',
     'cpmCPUTotal1min'                   => '1.3.6.1.4.1.9.9.109.1.1.1.1.4',

     # OLD-CISCO-CPU-MIB
     'avgBusy1'                          => '1.3.6.1.4.1.9.2.1.57.0'
     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'cisco', $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
    {
        return 0;
    }
    
    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    if( $devdetails->param('CiscoGeneric::disable-sensors') ne 'yes' )
    {
        # Check if temperature sensors are supported

        my $oidTempDescr = $dd->oiddef('ciscoEnvMonTemperatureStatusDescr');
        my $oidTempValue = $dd->oiddef('ciscoEnvMonTemperatureStatusValue');
        my $oidTempThrsh = $dd->oiddef('ciscoEnvMonTemperatureThreshold');
        my $oidTempState = $dd->oiddef('ciscoEnvMonTemperatureStatusState');

        if( defined $session->get_table( -baseoid => $oidTempValue ) )
        {
            $devdetails->setCap('ciscoTemperatureSensors');
            $data->{'ciscoTemperatureSensors'} = {};

            my $tempDescr = $session->get_table( -baseoid => $oidTempDescr );
            my $tempThrsh = $session->get_table( -baseoid => $oidTempThrsh );

            # Get the sensor states and ignore those notPresent(5)

            my $tempState = $session->get_table( -baseoid => $oidTempState );

            my $prefixLen = length( $oidTempDescr ) + 1;
            while( my( $oid, $descr ) = each %{$tempDescr} )
            {
                # Extract the sensor index from OID
                my $sIndex = substr( $oid, $prefixLen );

                if( $tempState->{$oidTempState.'.'.$sIndex} != 5 )
                {
                    $data->{'ciscoTemperatureSensors'}{$sIndex}{
                        'description'} = $descr;
                    $data->{'ciscoTemperatureSensors'}{$sIndex}{
                        'threshold'} = $tempThrsh->{$oidTempThrsh.'.'.$sIndex};
                }
            }
        }
    }

    if( $devdetails->param('CiscoGeneric::disable-psupplies') ne 'yes' )
    {
        # Check if power supply status is supported

        my $oidSupply = $dd->oiddef('ciscoEnvMonSupplyState');

        my $supplyTable = $session->get_table( -baseoid => $oidSupply );
        if( defined( $supplyTable ) )
        {
            $devdetails->setCap('ciscoPowerSupplies');
            $data->{'ciscoPowerSupplies'} = [];
            
            my $prefixLen = length( $oidSupply ) + 1;
            while( my( $oid, $val ) = each %{$supplyTable} )
            {
                # Extract the supply index from OID
                my $sIndex = substr( $oid, $prefixLen );
                
                #check if the value is not notPresent(5)
                if( $val != 5 )
                {
                    push( @{$data->{'ciscoPowerSupplies'}}, $sIndex );
                }
            }
        }
    }
    
    if( $devdetails->param('CiscoGeneric::disable-memory-pools') ne 'yes' )
    {
        my $eMemPool =
            $session->get_table( -baseoid =>
                                 $dd->oiddef('cempMemPoolName') );
        if( defined $eMemPool and scalar( %{$eMemPool} ) > 0 and
            $devdetails->isDevType('RFC2737_ENTITY_MIB') )
        {
            $devdetails->storeSnmpVars( $eMemPool );
            $devdetails->setCap('cempMemPool');
            $data->{'cempMemPool'} = {};

            foreach my $INDEX
                ( $devdetails->
                  getSnmpIndices($dd->oiddef('cempMemPoolName') ) )
            {
                # $INDEX is a pair entPhysicalIndex . cempMemPoolIndex
                my ( $phyIndex, $poolIndex ) = split('\.', $INDEX);

                my $poolName = $devdetails->
                    snmpVar($dd->oiddef('cempMemPoolName') . '.' . $INDEX );

                $poolName = 'Processor' unless $poolName;
                
                my $phyDescr = $data->{'entityPhysical'}{$phyIndex}{'descr'};
                my $phyName = $data->{'entityPhysical'}{$phyIndex}{'name'};
                
                $phyDescr = 'Processor' unless $phyDescr;
                $phyName = ('Chassis #' .
                            $phyIndex) unless $phyName;
               
                $data->{'cempMemPool'}{$INDEX} = {
                    'phyIndex'     => $phyIndex,
                    'poolIndex'    => $poolIndex,
                    'poolName'     => $poolName,                    
                    'phyDescr' => $phyDescr,
                    'phyName'  => $phyName
                    };
            }
        }
        else
        {
            my $MemoryPool =
                $session->get_table( -baseoid =>
                                     $dd->oiddef('ciscoMemoryPoolName') );

            if( defined $MemoryPool and scalar( %{$MemoryPool} ) > 0 )
            {
                $devdetails->storeSnmpVars( $MemoryPool );
                $devdetails->setCap('ciscoMemoryPool');
                
                $data->{'ciscoMemoryPool'} = {};
                
                foreach my $memType
                    ( $devdetails->
                      getSnmpIndices($dd->oiddef('ciscoMemoryPoolName')) )
                {
                    # According to CISCO-MEMORY-POOL-MIB, only types 1 to 5
                    # are static, and the rest are dynamic
                    # (of which none ever seen)
                    if( $memType <= 5 )
                    {
                        my $name =
                            $devdetails->
                            snmpVar($dd->oiddef('ciscoMemoryPoolName') .
                                    '.' . $memType );

                        $data->{'ciscoMemoryPool'}{$memType} = $name;
                    }
                }
            }
        }
    }

    if( $devdetails->param('CiscoGeneric::disable-cpu-stats') ne 'yes' )
    {
        my $ciscoCpuStats =
            $session->get_table( -baseoid => $dd->oiddef('cpmCPUTotalTable') );

        if( defined $ciscoCpuStats )
        {
            $devdetails->setCap('ciscoCpuStats');
            $devdetails->storeSnmpVars( $ciscoCpuStats );

            $data->{'ciscoCpuStats'} = {};

            # Find multiple CPU entries pointing to the same Phy index
            my %phyReferers = ();            
            foreach my $INDEX
                ( $devdetails->
                  getSnmpIndices($dd->oiddef('cpmCPUTotalPhysicalIndex') ) )
            {
                my $phyIndex = $devdetails->
                    snmpVar($dd->oiddef('cpmCPUTotalPhysicalIndex') .
                            '.' . $INDEX );
                $phyReferers{$phyIndex}++;
            }
                
            foreach my $INDEX
                ( $devdetails->
                  getSnmpIndices($dd->oiddef('cpmCPUTotalPhysicalIndex') ) )
            {
                $data->{'ciscoCpuStats'}{$INDEX} = {};

                my $phyIndex = $devdetails->
                    snmpVar($dd->oiddef('cpmCPUTotalPhysicalIndex') .
                            '.' . $INDEX );
                
                my $phyDescr;
                my $phyName;
                
                if( $phyIndex > 0 and
                    $devdetails->isDevType('RFC2737_ENTITY_MIB') )
                {
                    $phyDescr = $data->{'entityPhysical'}{$phyIndex}{'descr'};
                    $phyName = $data->{'entityPhysical'}{$phyIndex}{'name'};
                }
                
                $phyDescr = 'Central Processor' unless $phyDescr;
                $phyName = ('Chassis #' . $phyIndex) unless $phyName;
                    ;
                my $cpuNick = $phyName;
                $cpuNick =~ s/^\///;
                $cpuNick =~ s/\W/_/g;
                $cpuNick =~ s/_+/_/g;

                if( $phyReferers{$phyIndex} > 1 )
                {
                    $phyDescr .= ' (' . $INDEX . ')';
                    $cpuNick .= '_' . $INDEX;
                }
                
                $data->{'ciscoCpuStats'}{$INDEX} = {
                    'phy-index'  => $phyIndex,
                    'phy-name'   => $phyName,
                    'phy-descr'  => $phyDescr,
                    'phy-referers' => $phyReferers{$phyIndex},
                    'cpu-nick'   => $cpuNick };
                
                if( $devdetails->hasOID( $dd->oiddef('cpmCPUTotal1minRev') .
                                         '.' .  $INDEX ) )
                {
                    $data->{'ciscoCpuStats'}{$INDEX}{'stats-type'} = 'revised';
                }
            }
        }
        else
        {
            # Although OLD-CISCO-CPU-MIB is implemented in IOS only,
            # it is easier to leave it here in Generic

            if( $dd->checkSnmpOID('avgBusy1') )
            {
                $devdetails->setCap('old-ciscoCpuStats');
                push( @{$data->{'templates'}}, 'CiscoGeneric::old-cisco-cpu' );
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

    # Temperature Sensors

    if( $devdetails->hasCap('ciscoTemperatureSensors') )
    {
        # Create a subtree for the sensors
        my $subtreeName = 'Temperature_Sensors';

        my $fahrenheit =
            $devdetails->param('CiscoGeneric::use-fahrenheit') eq 'yes';

        my $param = {
            'node-display-name' => 'Temperature Sensors',
        };
        my $templates = [ 'CiscoGeneric::cisco-temperature-subtree' ];
        
        my $filePerSensor =
            $devdetails->param('CiscoGeneric::file-per-sensor') eq 'yes';
        
        $param->{'data-file'} = '%snmp-host%_sensors' .
            ($filePerSensor ? '_%sensor-index%':'') .
            ($fahrenheit ? '_fahrenheit':'') . '.rrd';

        my $subtreeNode = $cb->addSubtree( $devNode, $subtreeName,
                                           $param, $templates );
        
        foreach my $sIndex ( sort {$a<=>$b} keys
                             %{$data->{'ciscoTemperatureSensors'}} )
        {
            my $leafName = sprintf( 'sensor_%.2d', $sIndex );

            my $desc =
                $data->{'ciscoTemperatureSensors'}{$sIndex}{'description'};
            my $threshold =
                $data->{'ciscoTemperatureSensors'}{$sIndex}{'threshold'};

            if( $fahrenheit )
            {
                $threshold = $threshold * 1.8 + 32;
            }

            my $param = {
                'sensor-index'       => $sIndex,
                'sensor-description' => $desc,
                'upper-limit'        => $threshold
                };

            my $templates = ['CiscoGeneric::cisco-temperature-sensor' .
                             ($fahrenheit ? '-fahrenheit':'')];

            my $monitor = $data->{'ciscoTemperatureSensors'}{$sIndex}->{
                'selectorActions'}{'Monitor'};
            if( defined( $monitor ) )
            {
                $param->{'monitor'} = $monitor;
            }

            my $tset = $data->{'ciscoTemperatureSensors'}{$sIndex}->{
                'selectorActions'}{'TokensetMember'};
            if( defined( $tset ) )
            {
                $param->{'tokenset-member'} = $tset;
            }

            $cb->addLeaf( $subtreeNode, $leafName, $param, $templates );
        }
    }

    # Power supplies

    if( $devdetails->hasCap('ciscoPowerSupplies') )
    {
        # Create a subtree for the power supplies
        my $subtreeName = 'Power_Supplies';

        my $param = {
            'node-display-name' => 'Power Supplies',
            'comment' => 'Power supplies status',
            'precedence' => -600,
        };
        my $templates = [];
                
        $param->{'data-file'} = '%system-id%_power.rrd';

        my $monitor = $devdetails->param('CiscoGeneric::power-monitor');
        if( length( $monitor ) > 0 )
        {
            $param->{'monitor'} = $monitor;
        }

        my $subtreeNode = $cb->addSubtree( $devNode, $subtreeName,
                                           $param, $templates );
        
        foreach my $sIndex ( sort {$a<=>$b} @{$data->{'ciscoPowerSupplies'}} )
        {
            my $leafName = sprintf( 'power_%.2d', $sIndex );

            my $param = {
                'power-index'       => $sIndex
                };

            my $templates = ['CiscoGeneric::cisco-power-supply'];

            $cb->addLeaf( $subtreeNode, $leafName, $param, $templates );
        }
    }

    
    # Memory Pools

    if( $devdetails->hasCap('cempMemPool') or
        $devdetails->hasCap('ciscoMemoryPool') )
    {
        my $subtreeName = 'Memory_Usage';

        my $param = {
            'node-display-name' => 'Memory Usage',
            'precedence'        => '-100',
            'comment'           => 'Router memory utilization'
            };

        my $subtreeNode =
            $cb->addSubtree( $devNode, $subtreeName, $param,
                             ['CiscoGeneric::cisco-memusage-subtree']);

        if( $devdetails->hasCap('cempMemPool') )
        {
            foreach my $INDEX ( sort {
                $data->{'cempMemPool'}{$a}{'phyIndex'} <=>
                    $data->{'cempMemPool'}{$b}{'phyIndex'} or
                    $data->{'cempMemPool'}{$a}{'poolIndex'} <=>
                    $data->{'cempMemPool'}{$b}{'poolIndex'} }
                                keys %{$data->{'cempMemPool'}} )
            {
                my $pool = $data->{'cempMemPool'}{$INDEX};

                # Chop off the long chassis description, like
                # uBR7246VXR chassis, Hw Serial#: XXXXX, Hw Revision: A
                my $phyName = $pool->{'phyName'};                
                if( $phyName =~ /chassis/ )
                {
                    $phyName =~ s/,.+//;
                }
                
                my $poolSubtreeName =
                    $phyName . '_' . $pool->{'poolName'};
                $poolSubtreeName =~ s/^\///;
                $poolSubtreeName =~ s/\W/_/g;
                $poolSubtreeName =~ s/_+/_/g;
                
                my $param = {};

                $param->{'comment'} =
                    $pool->{'poolName'} . ' memory of ';
                if( $pool->{'phyDescr'} eq $pool->{'phyName'} )
                {
                    $param->{'comment'} .= $phyName;
                }
                else
                {
                    $param->{'comment'} .= 
                        $pool->{'phyDescr'} . ' in ' . $phyName;
                }
                
                $param->{'mempool-index'} = $INDEX;
                $param->{'mempool-phyindex'} = $pool->{'phyIndex'};
                $param->{'mempool-poolindex'} = $pool->{'poolIndex'};
                
                $param->{'mempool-name'} =  $pool->{'poolName'};
                $param->{'precedence'} =
                    sprintf("%d", 1000 -
                            $pool->{'phyIndex'} * 100 - $pool->{'poolIndex'});
                
                $cb->addSubtree( $subtreeNode, $poolSubtreeName, $param,
                                 [ 'CiscoGeneric::cisco-enh-mempool' ]);
            }
        }
        else
        {
            foreach my $memType
                ( sort {$a<=>$b} keys %{$data->{'ciscoMemoryPool'}} )
            {
                my $poolName = $data->{'ciscoMemoryPool'}{$memType};
                
                my $poolSubtreeName = $poolName;
                $poolSubtreeName =~ s/^\///;
                $poolSubtreeName =~ s/\W/_/g;
                $poolSubtreeName =~ s/_+/_/g;
                
                my $param = {
                    'comment'      => 'Memory Pool: ' . $poolName,
                    'mempool-type' => $memType,
                    'mempool-name' => $poolName,
                    'precedence'   => sprintf("%d", 1000 - $memType)
                    };

                $cb->addSubtree( $subtreeNode, $poolSubtreeName,
                                 $param, [ 'CiscoGeneric::cisco-mempool' ]);
            }
        }
    }

    if( $devdetails->hasCap('ciscoCpuStats') )
    {
        my $subtreeName = 'CPU_Usage';
        my $param = {
            'node-display-name' => 'CPU Usage',
            'precedence'         => '-500',
            'comment'            => 'Overall CPU busy percentage'
            };

        my $subtreeNode =
            $cb->addSubtree( $devNode, $subtreeName, $param,
                             ['CiscoGeneric::cisco-cpu-usage-subtree']);
        
        foreach my $INDEX ( sort {$a<=>$b} keys %{$data->{'ciscoCpuStats'}} )
        {
            my $cpu = $data->{'ciscoCpuStats'}{$INDEX};

            my $param = {
                'comment' => $cpu->{'phy-descr'} . ' in ' . $cpu->{'phy-name'}
                };

            # On newer dual-CPU routers, several (two seen) CPU entries
            # refer to the same physical entity. For such entries,
            # we map them directly to cpmCPUTotalTable index.
            if( $cpu->{'phy-referers'} > 1 )
            {
                $param->{'cisco-cpu-indexmap'} = $INDEX;
                $param->{'cisco-cpu-ref'} = $INDEX;
            }
            else
            {
                $param->{'entity-phy-index'} = $cpu->{'phy-index'};
                $param->{'cisco-cpu-ref'} = '%entity-phy-index%';
            }
            
            my @templates;

            if( $cpu->{'stats-type'} eq 'revised' )
            {
                push( @templates, 'CiscoGeneric::cisco-cpu-revised' );
            }
            else
            {
                push( @templates, 'CiscoGeneric::cisco-cpu' );
            }
            
            my $cpuNode = $cb->addSubtree( $subtreeNode, $cpu->{'cpu-nick'},
                                           $param, \@templates );
            
            my $tset = $cpu->{'selectorActions'}{'TokensetMember'};
            if( defined( $tset ) )
            {
                $cb->addLeaf( $cpuNode, 'CPU_Total_1min',
                              { 'tokenset-member' => $tset } );
            }
        }
    }
}



#######################################
# Selectors interface
#

$Torrus::DevDiscover::selectorsRegistry{'CiscoSensor'} = {
    'getObjects'      => \&getSelectorObjects,
    'getObjectName'   => \&getSelectorObjectName,
    'checkAttribute'  => \&checkSelectorAttribute,
    'applyAction'     => \&applySelectorAction,
};

$Torrus::DevDiscover::selectorsRegistry{'CiscoCPU'} = {
    'getObjects'      => \&getSelectorObjects,
    'getObjectName'   => \&getSelectorObjectName,
    'checkAttribute'  => \&checkSelectorAttribute,
    'applyAction'     => \&applySelectorAction,
};

## Objects are interface indexes

sub getSelectorObjects
{
    my $devdetails = shift;
    my $objType = shift;

    my $data = $devdetails->data();
    my @ret;
    
    if( $objType eq 'CiscoSensor' )
    {
        @ret = keys( %{$data->{'ciscoTemperatureSensors'}} );
    }
    elsif( $objType eq 'CiscoCPU' )
    {
        @ret = keys( %{$data->{'ciscoCpuStats'}} );
    }

    return( sort {$a<=>$b} @ret );
}


sub checkSelectorAttribute
{
    my $devdetails = shift;
    my $object = shift;
    my $objType = shift;
    my $attr = shift;
    my $checkval = shift;

    my $data = $devdetails->data();
    
    my $value;
    my $operator = '=~';
    
    if( $objType eq 'CiscoSensor' )
    {
        my $sensor = $data->{'ciscoTemperatureSensors'}{$object};
        if( $attr eq 'SensorDescr' )
        {
            $value = $sensor->{'description'};
        }
        else
        {
            Error('Unknown CiscoSensor selector attribute: ' . $attr);
            $value = '';
        }
    }
    elsif( $objType eq 'CiscoCPU' )
    {
        my $cpu = $data->{'ciscoCpuStats'}{$object};
        if( $attr eq 'CPUName' )
        {
            $value = $cpu->{'cpu-nick'};
        }
        elsif( $attr eq 'CPUDescr' )
        {
            $value = $cpu->{'cpu-descr'};
        }
        else
        {
            Error('Unknown CiscoCPU selector attribute: ' . $attr);
            $value = '';
        }        
    }        
    
    return eval( '$value' . ' ' . $operator . '$checkval' ) ? 1:0;
}


sub getSelectorObjectName
{
    my $devdetails = shift;
    my $object = shift;
    my $objType = shift;
    
    my $data = $devdetails->data();
    my $name;

    if( $objType eq 'CiscoSensor' )
    {
        $name = $data->{'ciscoTemperatureSensors'}{$object}{'description'};
    }
    elsif( $objType eq 'CiscoCPU' )
    {
        $name = $data->{'ciscoCpuStats'}{$object}{'cpu-nick'};
    }
    return $name;
}


my %knownSelectorActions =
    (
     'CiscoSensor' => {
         'Monitor' => 1,
         'TokensetMember' => 1 },
     'CiscoCPU' => {
         'TokensetMember' => 1 }
     );

                            
sub applySelectorAction
{
    my $devdetails = shift;
    my $object = shift;
    my $objType = shift;
    my $action = shift;
    my $arg = shift;

    my $data = $devdetails->data();
    my $objref;
    if( $objType eq 'CiscoSensor' )
    {
        $objref = $data->{'ciscoTemperatureSensors'}{$object};
    }
    elsif( $objType eq 'CiscoCPU' )
    {
        $objref = $data->{'ciscoCpuStats'}{$object};
    }
    
    if( $knownSelectorActions{$objType}{$action} )
    {
        $objref->{'selectorActions'}{$action} = $arg;
    }
    else
    {
        Error('Unknown Cisco selector action: ' . $action);
    }
}   



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
