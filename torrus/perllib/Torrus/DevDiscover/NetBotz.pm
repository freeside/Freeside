#  Copyright (C) 2009 Stanislav Sinyagin
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

# $Id: NetBotz.pm,v 1.1 2010-12-27 00:03:47 ivan Exp $

# NetBotz modular sensors

package Torrus::DevDiscover::NetBotz;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'NetBotz'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     'netBotzV2Products'     => '1.3.6.1.4.1.5528.100.20',
     );


our %sensor_types =
    ('temp'   => {
        'oid' => '1.3.6.1.4.1.5528.100.4.1.1.1',
        'template' => 'NetBotz::netbotz-temp-sensor',
        'max' => 'NetBotz::temp-max',
        },
     'humi'   => {
         'oid' => '1.3.6.1.4.1.5528.100.4.1.2.1',
         'template' => 'NetBotz::netbotz-humi-sensor',
         'max' => 'NetBotz::humi-max',
         },
     'dew'    => {
         'oid' => '1.3.6.1.4.1.5528.100.4.1.3.1',
         'template' => 'NetBotz::netbotz-dew-sensor',
         'max' => 'NetBotz::dew-max',
         },
     'audio'  => {
         'oid' => '1.3.6.1.4.1.5528.100.4.1.4.1',
         'template' => 'NetBotz::netbotz-audio-sensor'
         },
     'air' => {
         'oid' => '1.3.6.1.4.1.5528.100.4.1.5.1',
         'template' => 'NetBotz::netbotz-air-sensor'
         },
     'door' => {
         'oid' => '1.3.6.1.4.1.5528.100.4.2.2.1',
         'template' => 'NetBotz::netbotz-door-sensor'
         },
     );
     
     

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'netBotzV2Products',
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

    foreach my $stype (sort keys %sensor_types)
    {
        my $oid = $sensor_types{$stype}{'oid'};
        
        my $sensorTable = $session->get_table( -baseoid => $oid );
        
        if( defined( $sensorTable ) )
        {
            $devdetails->storeSnmpVars( $sensorTable );

            # store the sensor names to guarantee uniqueness
            my %sensorNames;
            
            foreach my $INDEX ($devdetails->getSnmpIndices($oid . '.1'))
            {
                my $label = $devdetails->snmpVar( $oid . '.4.' . $INDEX );
                
                if( $sensorNames{$label} )
                {
                    Warn('Duplicate sensor names: ' . $label);
                    $sensorNames{$label}++;
                }
                else
                {
                    $sensorNames{$label} = 1;
                }
                
                if( $sensorNames{$label} > 1 )
                {
                    $label .= sprintf(' %d', $sensorNames{$label});
                }
                
                my $leafName = $label;
                $leafName =~ s/\W/_/g;

                my $param = {
                    'netbotz-sensor-index' => $INDEX,
                    'node-display-name' => $label,
                    'graph-title' => $label,
                    'precedence' => sprintf('%d', 1000 - $INDEX)
                };

                if( defined( $sensor_types{$stype}{'max'} ) )
                {
                    my $max =
                        $devdetails->param($sensor_types{$stype}{'max'});
                    
                    if( defined($max) and $max > 0 )
                    {
                        $param->{'upper-limit'} = $max;
                    }
                }
                

                $data->{'NetBotz'}{$INDEX} = {
                    'param'    => $param,
                    'leafName' => $leafName,
                    'template' => $sensor_types{$stype}{'template'}};
            }
        }        
    }
    
    if( not defined($data->{'param'}{'comment'}) or
        length($data->{'param'}{'comment'}) == 0 )
    {
        $data->{'param'}{'comment'} = 'NetBotz environment sensors';
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my $data = $devdetails->data();

    foreach my $INDEX ( sort {$a<=>$b} keys %{$data->{'NetBotz'}} )
    {
        my $ref = $data->{'NetBotz'}{$INDEX};
        
        $cb->addLeaf( $devNode, $ref->{'leafName'}, $ref->{'param'},
                      [$ref->{'template'}] );
    }
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
