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

# $Id: FTOS.pm,v 1.1.1.1.2.1 2011-12-16 22:43:56 ivan Exp $
# Jon Nistor <nistor at snickers.org>

# Force10 Networks Real Time Operating System Software
#
# NOTE: FTOS::disable-cpu
#       FTOS::disable-power
#       FTOS::disable-temperature
#       FTOS::use-fahrenheit
#       FTOS::file-per-sensor (affects both power and temperature)

package Torrus::DevDiscover::FTOS;

use strict;
use Torrus::Log;

$Torrus::DevDiscover::registry{'FTOS'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # FORCE10-SMI
     'f10Products'           => '1.3.6.1.4.1.6027.1',

     # F10-CHASSIS-MIB
     'chType'                => '1.3.6.1.4.1.6027.3.1.1.1.1.0',
     'chSerialNumber'        => '1.3.6.1.4.1.6027.3.1.1.1.2.0',
     'chSysPowerSupplyIndex' => '1.3.6.1.4.1.6027.3.1.1.2.1.1.1',
     'chSysCardSlotIndex'    => '1.3.6.1.4.1.6027.3.1.1.2.3.1.1',
     'chSysCardNumber'       => '1.3.6.1.4.1.6027.3.1.1.2.3.1.3',
     'chRpmCpuIndex'         => '1.3.6.1.4.1.6027.3.1.1.3.7.1.1',

     # FORCE10-SYSTEM-COMPONENT-MIB
     'camUsagePartDesc'      => '1.3.6.1.4.1.6027.3.7.1.1.1.1.4'
     );


our %f10ChassisType =
    (
     '1'   => 'Force10 E1200 16-slot switch/router',
     '2'   => 'Force10 E600 9-slot switch/router',
     '3'   => 'Force10 E300 8-slot switch/router',
     '4'   => 'Force10 E150 8-slot switch/router',
     '5'   => 'Force10 E610 9-slot switch/router',
     '6'   => 'Force10 C150 6-slot switch/router',
     '7'   => 'Force10 C300 10-slot switch/router',
     '8'   => 'Force10 E1200i 16-slot switch/router',
     '9'   => 'Force10 S2410 10GbE switch',
     '10'  => 'Force10 S2410 10GbE switch',
     '11'  => 'Force10 S50 access switch',
     '12'  => 'Force10 S50e access switch',
     '13'  => 'Force10 S50v access switch',
     '14'  => 'Force10 S50nac access switch',
     '15'  => 'Force10 S50ndc access switch',
     '16'  => 'Force10 S25pdc access switch',
     '17'  => 'Force10 S25pac access switch',
     '18'  => 'Force10 S25v access switch',
     '19'  => 'Force10 S25n access switch'
     );

our %f10CPU =
    (
     '1'   => 'Control Processor',
     '2'   => 'Routing Processor #1',
     '3'   => 'Routing Processor #2'
     );


# Not all interfaces are normally needed to monitor.
# You may override the interface filtering in devdiscover-siteconfig.pl:
# redefine $Torrus::DevDiscover::FTOS::interfaceFilter
# or define $Torrus::DevDiscover::FTOS::interfaceFilterOverlay

our $interfaceFilter;
our $interfaceFilterOverlay;
my %ftosInterfaceFilter;

if( not defined( $interfaceFilter ) )
{
    $interfaceFilter = \%ftosInterfaceFilter;
}


# Key is some unique symbolic name, does not mean anything
#  ifType is the number to match the interface type
# ifDescr is the regexp to match the interface description
%ftosInterfaceFilter =
    (
     'other' => {
         'ifType'  => 1,                     # other
     },
     'loopback' => {
         'ifType'  => 24,                    # softwareLoopback
     },
     
     );


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'f10Products',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
    {
        return 0;
    }
    
    # Systems running FTOS will have chassisType, SFTOS will not.
    if( not $dd->checkSnmpOID('chType') )
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

    # NOTE: Comments and Serial number of device
    my $chassisSerial = $dd->retrieveSnmpOIDs( 'chType', 'chSerialNumber' );

    if( defined( $chassisSerial ) )
    {
        $data->{'param'}{'comment'} =
            $f10ChassisType{$chassisSerial->{'chType'}} .
            ', Hw Serial#: ' . $chassisSerial->{'chSerialNumber'};
    }
    else
    {
        $data->{'param'}{'comment'} = "Force10 Networks switch/router";
    }

    # PROG: CPU statistics
    if( $devdetails->param('FTOS::disable-cpu') ne 'yes' )
    {
        # Poll table to translate the CPU Index to a Name
        my $ftosCpuTable =
            $session->get_table( -baseoid => $dd->oiddef('chRpmCpuIndex') );

        $devdetails->storeSnmpVars( $ftosCpuTable );

        if( defined( $ftosCpuTable ) )
        {
            $devdetails->setCap('ftosCPU');

            # Find the index of the CPU
            foreach my $ftosCPUidx ( $devdetails->getSnmpIndices
                                     ( $dd->oiddef('chRpmCpuIndex') ) )
            {
                my $cpuType = $dd->oiddef('chRpmCpuIndex') . "." . $ftosCPUidx;
                my $cpuName = $f10CPU{$ftosCpuTable->{$cpuType}};

                Debug("FTOS::CPU index $ftosCPUidx, $cpuName");

                # Construct the data ...
                $data->{'ftosCPU'}{$ftosCPUidx} = $cpuName;
            }
        }
        else
        {
            Debug("FTOS::CPU No CPU information found, old sw?");
        }
    } # END: CPU


    # PROG: Power Supplies
    if( $devdetails->param('FTOS::disable-power') ne 'yes' )
    {
        # Poll table of power supplies
        my $ftosPSUTable =
            $session->get_table( -baseoid =>
                                 $dd->oiddef('chSysPowerSupplyIndex') );

        $devdetails->storeSnmpVars( $ftosPSUTable );

        if( defined( $ftosPSUTable ) )
        {
            $devdetails->setCap('ftosPSU');

            # Find the Index of the Power Supplies
            foreach my $ftosPSUidx ( $devdetails->getSnmpIndices
                                     ($dd->oiddef('chSysPowerSupplyIndex')) )
            {
                Debug("FTOS::PSU index $ftosPSUidx");

                push( @{$data->{'ftosPSU'}}, $ftosPSUidx );
            }
        }
    } # END: PSU


    # PROG: Temperature
    if( $devdetails->param('FTOS::disable-sensors') ne 'yes' )
    {
        # Check if temperature sensors are supported
        my $sensorTable =
            $session->get_table( -baseoid =>
                                 $dd->oiddef('chSysCardSlotIndex') );
        $devdetails->storeSnmpVars( $sensorTable );

        my $sensorCard =
            $session->get_table( -baseoid => $dd->oiddef('chSysCardNumber') );
        $devdetails->storeSnmpVars( $sensorCard );


        if( defined( $sensorTable ) )
        {
            $devdetails->setCap('ftosSensor');
            
            foreach my $sensorIdx ( $devdetails->getSnmpIndices
                                    ( $dd->oiddef('chSysCardSlotIndex') ) )
            {
                my $sensorCard =
                    $devdetails->snmpVar( $dd->oiddef('chSysCardNumber') .
                                          '.' . $sensorIdx );

                $data->{'ftosSensor'}{$sensorIdx} = $sensorCard;

                Debug("FTOS::Sensor index $sensorIdx, card $sensorCard");
            }
        } # END if: $sensorTable
    } # END: disable-sensors


    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    my $data = $devdetails->data();


    # PROG: CPU processing
    if( $devdetails->hasCap('ftosCPU') )
    {
        my $nodeTop = $cb->addSubtree( $devNode, 'CPU_Usage', undef,
                                       [ 'FTOS::ftos-cpu-subtree'] );

        foreach my $CPUidx ( sort {$a <=> $b} keys %{$data->{'ftosCPU'}} )
        {
            my $CPUName = $data->{'ftosCPU'}{$CPUidx};
            my $subName = sprintf( 'CPU_%.2d', $CPUidx );

            my $nodeCPU = $cb->addSubtree( $nodeTop, $subName,
                                           { 'comment'   => $CPUName,
                                             'cpu-index' => $CPUidx,
                                             'cpu-name'  => $CPUName },
                                           [ 'FTOS::ftos-cpu' ] );
        }
    } # END if ftosCPU


    # PROG: Power supplies
    if( $devdetails->hasCap('ftosPSU') )
    {
        my $subtreeName = "Power_Supplies";
        my $param       = { 'comment'    => 'Power supplies status',
                            'precedence' => -600 };
        my $filePerSensor 
            = $devdetails->param('FTOS::file-per-sensor') eq 'yes';
        my $templates   = [];

        $param->{'data-file'} = '%snmp-host%_power' .
            ($filePerSensor ? '_%power-index%':'') .
            '.rrd';

        my $nodeTop = $cb->addSubtree( $devNode, $subtreeName,
                                       $param, $templates );


        foreach my $PSUidx ( sort {$a <=> $b} @{$data->{'ftosPSU'}} )
        {
            my $leafName = sprintf( 'power_%.2d', $PSUidx );

            my $nodePSU = $cb->addLeaf( $nodeTop, $leafName, 
                                        { 'power-index' => $PSUidx },
                                        [ 'FTOS::ftos-power-supply-leaf' ]);
        }
    }


    # PROG: Temperature sensors
    if( $devdetails->hasCap('ftosSensor') )
    {
        my $subtreeName = "Temperature_Sensors";
        my $param       = {};
        my $fahrenheit  = $devdetails->param('FTOS::use-fahrenheit') eq 'yes';
        my $filePerSensor 
            = $devdetails->param('FTOS::file-per-sensor') eq 'yes';
        my $templates   = [ 'FTOS::ftos-temperature-subtree' ];

        $param->{'data-file'} = '%snmp-host%_sensors' .
            ($filePerSensor ? '_%sensor-index%':'') .
            ($fahrenheit ? '_fahrenheit':'') . '.rrd';

        my $subtreeNode = $cb->addSubtree( $devNode, $subtreeName,
                                           $param, $templates );

        foreach my $sIndex ( sort {$a<=>$b} keys %{$data->{'ftosSensor'}} )
        {
            my $leafName   = sprintf( 'sensor_%.2d', $sIndex );
            my $threshold  = 60;  # Forced value for the time being, 60 degC
            my $sensorCard = $data->{'ftosSensor'}{$sIndex};

            if( $fahrenheit )
            {
                $threshold = $threshold * 1.8 + 32;
            }

            my $param = {
                'sensor-index'       => $sIndex,
                'sensor-description' => 'Module ' . $sensorCard,
                'upper-limit'        => $threshold
                };

            my $templates = ['FTOS::ftos-temperature-sensor' .
                             ($fahrenheit ? '-fahrenheit':'')];

            $cb->addLeaf( $subtreeNode, $leafName, $param, $templates );
        } 
    }
}


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
