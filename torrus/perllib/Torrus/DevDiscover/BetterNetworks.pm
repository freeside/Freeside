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

# $Id: BetterNetworks.pm,v 1.1 2010-12-27 00:03:55 ivan Exp $
# Marc Haber <mh+torrus-devel@zugschlus.de>
# Redesigned by Stanislav Sinyagin

# Better Networks Ethernet Box

package Torrus::DevDiscover::BetterNetworks;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'BetterNetworks'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     'BNEversion'          => '1.3.6.1.4.1.14848.2.1.1.1.0',
     'BNElocation'         => '1.3.6.1.4.1.14848.2.1.1.2.0',
     'BNEtempunit'         => '1.3.6.1.4.1.14848.2.1.1.3.0',
     'BNEuptime'           => '1.3.6.1.4.1.14848.2.1.1.7.0',
     'BNEsensorTable'      => '1.3.6.1.4.1.14848.2.1.2',
     'BNEsensorName'       => '1.3.6.1.4.1.14848.2.1.2.1.2',
     'BNEsensorType'       => '1.3.6.1.4.1.14848.2.1.2.1.3',
     'BNEsensorValid'      => '1.3.6.1.4.1.14848.2.1.2.1.7',
     );


our %sensorTypes =
    (
     1 => {
         'comment' => 'Temperature sensor',
     },
     2 => {
         'comment' => 'Brightness sensor',
         'label' => 'Lux',
     },
     3 => {
         'comment' => 'Humidity sensor',
         'label' => 'Percent RH',
     },
     4 => {
         'comment' => 'Switch contact',
     },
     5 => {
         'comment' => 'Voltage meter',
     },
     6 => {
         'comment' => 'Smoke sensor',
     },
     );

our %tempUnits =
    (
     0 => 'Celsius',
     1 => 'Fahrenheit',
     2 => 'Kelvin'
     );


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->checkSnmpOID( 'BNEuptime' ) )
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

    my $unitInfo = $dd->retrieveSnmpOIDs('BNEversion',
                                         'BNElocation',
                                         'BNEtempunit');
    if( not defined( $unitInfo ) )
    {
        Error('Error retrieving Better Networks Ethernet Box device details');
        return 0;
    }
    
    # sensor support
    my $sensorTable = $session->get_table( -baseoid =>
                                           $dd->oiddef('BNEsensorTable') );
    if( defined( $sensorTable ) )
    {
        $devdetails->storeSnmpVars( $sensorTable );

        # store the sensor names to guarantee uniqueness
        my %sensorNames;
            
        foreach my $INDEX
            ( $devdetails->getSnmpIndices($dd->oiddef('BNEsensorName') ) )
        {
            if( $devdetails->snmpVar( $dd->oiddef('BNEsensorValid') .
                                      '.' . $INDEX ) == 0 )
            {
                next;
            }
                
            my $type = $devdetails->snmpVar( $dd->oiddef('BNEsensorType') .
                                             '.' . $INDEX );
            my $name = $devdetails->snmpVar( $dd->oiddef('BNEsensorName')
                                             . '.' . $INDEX );

            if( $sensorNames{$name} )
            {
                Warn('Duplicate sensor names: ' . $name);
                $sensorNames{$name}++;
            }
            else
            {
                $sensorNames{$name} = 1;
            }

            if( $sensorNames{$name} > 1 )
            {
                $name .= sprintf(' %d', $sensorNames{$name});
            }
            
            my $leafName = $name;
            $leafName =~ s/\W/_/g;

            my $param = {
                'bne-sensor-index' => $INDEX,
                'node-display-name' => $name,
                'precedence' => sprintf('%d', 1000 - $INDEX)
                };
            
            if( defined( $sensorTypes{$type} ) )
            {
                $param->{'comment'} =
                    sprintf('%s: %s', $sensorTypes{$type}{'comment'}, $name);
                if( $type != 1 )
                {
                    if( defined( $sensorTypes{$type}{'label'} ) )
                    {
                        $param->{'vertical-label'} =
                            $sensorTypes{$type}{'label'};
                    }
                }
                else
                {
                    $param->{'vertical-label'} =
                        $tempUnits{$unitInfo->{'BNEtempunit'}};
                }
            }
            else
            {
                $param->{'comment'} = 'Unknown sensor type';
            }

            $data->{'BNEsensor'}{$INDEX}{'param'} = $param;
            $data->{'BNEsensor'}{$INDEX}{'leafName'} = $leafName;            
        }

        if( scalar( %{$data->{'BNEsensor'}} ) > 0 )
        {
            $devdetails->setCap('BNEsensor');

            my $devComment = 
                'BetterNetworks EthernetBox, ' . $unitInfo->{'BNEversion'};
            if( $unitInfo->{'BNElocation'} =~ /\w/ )
            {
                $devComment .= ', Location: ' . 
                    $unitInfo->{'BNElocation'};
            }
            $data->{'param'}{'comment'} = $devComment;
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

    if( $devdetails->hasCap('BNEsensor') )
    {
        foreach my $INDEX ( sort {$a<=>$b} keys %{$data->{'BNEsensor'}} )
        {
            my $param = $data->{'BNEsensor'}{$INDEX}{'param'};
            my $leafName = $data->{'BNEsensor'}{$INDEX}{'leafName'};
            
            $cb->addLeaf( $devNode, $leafName, $param,
                          ['BetterNetworks::betternetworks-sensor'] );
        }
    }
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
