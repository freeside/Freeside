#  Copyright (C) 2010 Roman Hochuli
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

# $Id: Jacarta.pm,v 1.1 2010-12-27 00:03:55 ivan Exp $

# Sensor-MIBs of Jacarta iMeter-Products


package Torrus::DevDiscover::Jacarta;

use strict;
use Torrus::Log;
use Switch;
use Data::Dumper;


$Torrus::DevDiscover::registry{'Jacarta'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     'jacarta'             => '1.3.6.1.4.1.19011',
     'sensorEntry'         => '1.3.6.1.4.1.19011.2.3.1.1',
     'sensorIndex'         => '1.3.6.1.4.1.19011.2.3.1.1.1',
     'sensorDescription'   => '1.3.6.1.4.1.19011.2.3.1.1.2',
     'sensorType'          => '1.3.6.1.4.1.19011.2.3.1.1.3',
     'sensorValue'         => '1.3.6.1.4.1.19011.2.3.1.1.4',
     'sensorUnit'          => '1.3.6.1.4.1.19011.2.3.1.1.5',
     );


our %sensor_types =
    (
     2 => {
         'template' => 'Jacarta::imeter-humi-sensor',
         'max' => 'NetBotz::humi-max',
     },
     3 => {
         'template' => 'Jacarta::imeter-temp-sensor',
         'max' => 'NetBotz::dew-max',
     },
     5 => {
         'template' => 'Jacarta::imeter-amps-sensor',
         'max' => 'NetBotz::dew-max',
     },     
     
     );



sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'jacarta',
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

    my $data = $devdetails->data();
    my $session = $dd->session();

    $data->{'Jacarta'} = {};
    
    my $sensorTable =
        $session->get_table( -baseoid => $oiddef{'sensorEntry'} );

    if( not defined( $sensorTable ) )
    {
        return 1;
    }
    
    $devdetails->storeSnmpVars( $sensorTable );
        
    # store the sensor names to guarantee uniqueness
    my %sensorNames;
    
    foreach my $INDEX
        ($devdetails->getSnmpIndices( $oiddef{'sensorIndex'} ))
    {
        my $sensorType =
            $devdetails->snmpVar( $oiddef{'sensorType'} . '.' .
                                  $INDEX);
        my $sensorName =
            $devdetails->snmpVar( $oiddef{'sensorDescription'} . '.' .
                                  $INDEX);
        
        if( not defined( $sensor_types{$sensorType} ) )
        {
            Error('Sensor ' . $INDEX . ' of unknown type: ' . $sensorType);
            next;
        }
        
        if( $sensorNames{$sensorName} )
        {
            Warn('Duplicate sensor names: ' . $sensorName);
            $sensorNames{$sensorName}++;
        }
        else
        {
            $sensorNames{$sensorName} = 1;
        }
        
        if( $sensorNames{$sensorName} > 1 )
        {
            $sensorName .= sprintf(' %d', $INDEX);
        }
        
        my $leafName = $sensorName;
        $leafName =~ s/\W/_/g;
        
        my $param = {
            'imeter-sensor-index' => $INDEX,
            'node-display-name' => $sensorName,
            'graph-title' => $sensorName,
            'precedence' => sprintf('%d', 1000 - $INDEX)
            };

        
        if( defined( $sensor_types{$sensorType}{'max'} ) )
        {
            my $max =
                $devdetails->param($sensor_types{$sensorType}{'max'});
            
            if( defined($max) and $max > 0 )
            {
                $param->{'upper-limit'} = $max;
            }
        }
                
        $data->{'Jacarta'}{$INDEX} = {
            'param'    => $param,
            'leafName' => $leafName,
            'template' => $sensor_types{$sensorType}{'template'}};
        
        Debug('Found Sensor ' . $INDEX . ' of type ' . $sensorType .
              ', named ' . $sensorName );
    }
    
    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    
    my $data = $devdetails->data();
    
    my $param = {
        'node-display-name' => 'Sensors',
        'comment' => 'All sensors connected via this iMeter Master',
    };
    
    my $sensorTree =
        $cb->addSubtree( $devNode, 'Sensors', $param );

    foreach my $INDEX ( sort {$a<=>$b} keys %{$data->{'Jacarta'}} )
    {
        my $ref = $data->{'Jacarta'}{$INDEX};
        
        $cb->addLeaf( $sensorTree, $ref->{'leafName'}, $ref->{'param'},
                      [$ref->{'template'}] );
    }
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
