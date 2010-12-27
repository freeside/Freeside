#
#  Discovery module for Liebert HVAC systems
#
#  Copyright (C) 2008 Jon Nistor
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

# $Id: Liebert.pm,v 1.1 2010-12-27 00:03:50 ivan Exp $
# Jon Nistor <nistor at snickers.org>
#
# NOTE: Options for this module
#       Liebert::use-fahrenheit
#	Liebert::disable-temperature
#	Liebert::disable-humidity
#	Liebert::disable-state
#	Liebert::disable-stats
#
# NOTE: This module supports both Fahrenheit and Celcius, but for ease of
#       module and cleanliness we will convert Celcius into Fahrenheit
#       instead of polling for Fahrenheit directly.
#

# Liebert discovery module
package Torrus::DevDiscover::Liebert;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'Liebert'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

our %oiddef =
    (
     # LIEBERT-GP-REGISTRATION-MIB
     'GlobalProducts'	  => '1.3.6.1.4.1.476.1.42',

     # LIEBERT-GP-AGENT-MIB
     'Manufacturer'       => '1.3.6.1.4.1.476.1.42.2.1.1.0',
     'Model'              => '1.3.6.1.4.1.476.1.42.2.1.2.0',
     'FirmwareVer'        => '1.3.6.1.4.1.476.1.42.2.1.3.0',
     'SerialNum'          => '1.3.6.1.4.1.476.1.42.2.1.4.0',
     'PartNum'            => '1.3.6.1.4.1.476.1.42.2.1.5.0',

     'TemperatureIdDegF'  => '1.3.6.1.4.1.476.1.42.3.4.1.2.3.1.1',
     'TemperatureIdDegC'  => '1.3.6.1.4.1.476.1.42.3.4.1.3.3.1.1',
     'HumidityIdRel'      => '1.3.6.1.4.1.476.1.42.3.4.2.2.3.1.1',

     'lgpEnvState'                => '1.3.6.1.4.1.476.1.42.3.4.3',
     'lgpEnvStateCoolingCapacity' => '1.3.6.1.4.1.476.1.42.3.4.3.9.0',
     'lgpEnvStatistics'           => '1.3.6.1.4.1.476.1.42.3.4.6',

     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch ( 'GlobalProducts',
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

    # PROG: Grab versions, serials and type of chassis.
    my $Info = $dd->retrieveSnmpOIDs ( 'Manufacturer', 'Model',
                        'FirmwareVer', 'SerialNum', 'PartNum' );

    # SNMP: System comment
    $data->{'param'}{'comment'} =
            $Info->{'Manufacturer'} . " " . $Info->{'Model'} . ", Version: " .
            $Info->{'FirmwareVer'} . ", Serial: " . $Info->{'SerialNum'};

    # The Liebert HVAC snmp implementation requires a lower number
    # of pdu's to be sent to it.
    $data->{'param'}{'snmp-oids-per-pdu'} = 10;

    # Temperature
    if( $devdetails->param('Liebert::disable-temperature') ne 'yes' ) 
    {
        $devdetails->setCap('env-temperature');

        if( $devdetails->param('Liebert::use-fahrenheit') ne 'yes' )
        {
            # ENV: Temperature in Celcius
            my $idTable = $session->get_table(
                 -baseoid => $dd->oiddef('TemperatureIdDegC') );
            $devdetails->storeSnmpVars( $idTable );

            if( defined( $idTable ) )
            {
                $devdetails->setCap('env-temperature-celcius');

                foreach my $index ( $devdetails->getSnmpIndices(
                                    $dd->oiddef('TemperatureIdDegC') ) )
                {
                    Debug("Liebert: Temp (degC) index: $index");
                    $data->{'liebert'}{'tempidx'}{$index} = "celcius";
                }
            }
        } else {
            # ENV: Temperature in Fahrenheit
            my $idTable = $session->get_table(
                 -baseoid => $dd->oiddef('TemperatureIdDegF') );
            $devdetails->storeSnmpVars( $idTable );

            if( defined( $idTable ) )
            {
                $devdetails->setCap('env-temperature-fahrenheit');

                foreach my $index ( $devdetails->getSnmpIndices(
                                    $dd->oiddef('TemperatureIdDegF') ) )
                {
                    Debug("Liebert: Temp (degF) index: $index");
                    $data->{'liebert'}{'tempidx'}{$index} = "fahrenheit";
                }
            }
        }
    }

    # ENV: Humidity
    if( $devdetails->param('Liebert::disable-humidity') ne 'yes' )
    {
        my $idTable = $session->get_table(
                 -baseoid => $dd->oiddef('HumidityIdRel') );
        $devdetails->storeSnmpVars( $idTable );

        if( defined( $idTable ) )
        {
            $devdetails->setCap('env-humidity');
            foreach my $index ( $devdetails->getSnmpIndices(
                                $dd->oiddef('HumidityIdRel') ) )
            {
                Debug("Liebert: humidity index: $index");
                $data->{'liebert'}{'humididx'}{$index} = "humidity";
            }
        }
    }

    # ENV: State
    if( $devdetails->param('Liebert::disable-state') ne 'yes' )
    {
        my $stateTable = $session->get_table(
                 -baseoid => $dd->oiddef('lgpEnvState') );
        $devdetails->storeSnmpVars( $stateTable );

        if( defined( $stateTable ) )
        {
            $devdetails->setCap('env-state');

            # PROG: Check to see if Firmware is new enough for Capacity
            if( $dd->checkSnmpOID('lgpEnvStateCoolingCapacity') )
            {
                $devdetails->setCap('env-state-capacity');
            }
        }
    }

    # Statistics
    if( $devdetails->param('Liebert::disable-stats') ne 'yes' )
    {
        my $statsTable = $session->get_table(
                 -baseoid => $dd->oiddef('lgpEnvStatistics') );
        $devdetails->storeSnmpVars( $statsTable );

        if( defined( $statsTable ) )
        {
            $devdetails->setCap('env-stats');
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

    if( $devdetails->hasCap('env-temperature') )
    {
        # All place-setting variables default to Celcius
        my @template;
        my $dataFile   = "%system-id%_temperature.rrd";
        my $fahrenheit = 0;
        my $snmpVar    = 3;
        my $tempUnit   = "C";
        my $tempScale  = "Celcius";
        my $tempLowLim = 15;
        my $tempUppLim = 70;

        if( $devdetails->hasCap('env-temperature-fahrenheit') )
        {
            $dataFile   = "%system-id%_temperature_f.rrd";
            $fahrenheit	= 1;
            $snmpVar    = 2;
            $tempUnit   = "F";
            $tempScale  = "Fahrenheit";
            $tempLowLim = $tempLowLim * 1.8 + 32;
            $tempUppLim = $tempUppLim * 1.8 + 32;
            push(@template, "Liebert::temperature-sensor-fahrenheit");
        } else {
            push(@template, "Liebert::temperature-sensor");
        }

        my $paramSubTree = {
            'data-file'      => $dataFile,
            'temp-idx'       => $snmpVar,
            'temp-lower'     => $tempLowLim,
            'temp-scale'     => $tempUnit,
            'temp-upper'     => $tempUppLim,
            'vertical-label' => "degrees $tempScale"
        };
        my $nodeTemp = $cb->addSubtree( $devNode, 'Temperature', $paramSubTree,
                                      [ 'Liebert::temperature-subtree' ] );

	# ----------------------------------------------------------------
        # PROG: Figure out how many indexes we have
        foreach my $index ( keys %{$data->{'liebert'}{'tempidx'}} )
        {
            my $dataFile = "%system-id%_sensor_$index" . 
                           ($fahrenheit ? '_fahrenheit':'') . ".rrd";
            Debug("Liebert: Temperature idx: $index : $tempScale");
            my $param = {
                'comment'    => "Sensor: $index",
                'data-file'  => $dataFile,
                'sensor-idx' => $index
            };

            $cb->addSubtree( $nodeTemp, 'sensor_' . $index, $param,
                        [ @template ] );
        } # END: foreach my $index
    } # END: env-temperature


    # Humidity
    if( $devdetails->hasCap('env-humidity') )
    {
        my $nodeHumidity = $cb->addSubtree( $devNode, "Humidity", undef,
                                          [ 'Liebert::humidity-subtree' ] );

        # PROG: Figure out how many sensors we have
        foreach my $index ( keys %{$data->{'liebert'}{'humididx'}} )
        {
            Debug("Liebert: Humidity idx: $index");

            my $param = {
                'comment'   => "Sensor: " . $index,
                'humid-idx' => $index
            };

            $cb->addSubtree( $nodeHumidity, 'sensor_' . $index, $param,
                           [ 'Liebert::humidity-sensor' ] );
        }

    } # END of hasCap


    # State of the system
    if( $devdetails->hasCap('env-state') )
    {
        my $nodeState = $cb->addSubtree( $devNode, 'State', undef,
                                       [ 'Liebert::state-subtree' ] );

        if( $devdetails->hasCap('env-state-capacity') )
        {
            $cb->addSubtree( $devNode, 'State', undef,
                           [ 'Liebert::state-capacity' ] );
        }
    }
}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
