#  Copyright (C) 2012 Freeside Internet Services, Inc.
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

# Ractivity Power Distribution Unit

package Torrus::DevDiscover::Ractivity;

use strict;
use Torrus::Log;

$Torrus::DevDiscover::registry{'Ractivity'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
};

our %oiddef =
(
    #'racktivity'           => '1.3.6.1.4.1.34097',
    'product'              => '1.3.6.1.4.1.34097.1',
    'name'                 => '1.3.6.1.4.1.34097.1.1',
    'version'              => '1.3.6.1.4.1.34097.1.2',
    'date'                 => '1.3.6.1.4.1.34097.1.3',
    'general'              => '1.3.6.1.4.1.34097.2',
    'Voltage'              => '1.3.6.1.4.1.34097.2.1',
    'MaxTotCurentTime'     => '1.3.6.1.4.1.34097.2.10',
    'TotKwh'               => '1.3.6.1.4.1.34097.2.11',
    'Intrusion'            => '1.3.6.1.4.1.34097.2.12',
    'Airflow'              => '1.3.6.1.4.1.34097.2.13',
    'Beep'                 => '1.3.6.1.4.1.34097.2.14',
    'ControllerName'       => '1.3.6.1.4.1.34097.2.15',
    'RackPosition'         => '1.3.6.1.4.1.34097.2.16',
    'Frequency'            => '1.3.6.1.4.1.34097.2.2',
    'TotCurrent'           => '1.3.6.1.4.1.34097.2.3',
    'TotPower'             => '1.3.6.1.4.1.34097.2.4',
    'TemperatureInside'    => '1.3.6.1.4.1.34097.2.5',
    'HumidityInside'       => '1.3.6.1.4.1.34097.2.6',
    'MaxTotCurrentWarning' => '1.3.6.1.4.1.34097.2.7',
    'MaxTotCurentOff'      => '1.3.6.1.4.1.34097.2.8',
    'MaxTotCurrent'        => '1.3.6.1.4.1.34097.2.9',
    'port'                 => '1.3.6.1.4.1.34097.3',
    'portTable'            => '1.3.6.1.4.1.34097.3.1',
    'portEntry'            => '1.3.6.1.4.1.34097.3.1.1',
    'PortNr'               => '1.3.6.1.4.1.34097.3.1.1.1',
    'MaxCurrent'           => '1.3.6.1.4.1.34097.3.1.1.10',
    'MaxCurrentTime'       => '1.3.6.1.4.1.34097.3.1.1.11',
    'MaxCurrentWarning'    => '1.3.6.1.4.1.34097.3.1.1.12',
    'MaxCurrentOff'        => '1.3.6.1.4.1.34097.3.1.1.13',
    'Priority'             => '1.3.6.1.4.1.34097.3.1.1.14',
    'DelayOn'              => '1.3.6.1.4.1.34097.3.1.1.15',
    'PortName'             => '1.3.6.1.4.1.34097.3.1.1.2',
    'Current'              => '1.3.6.1.4.1.34097.3.1.1.3',
    'RealPower'            => '1.3.6.1.4.1.34097.3.1.1.4',
    'ApparentPower'        => '1.3.6.1.4.1.34097.3.1.1.5',
    'PowerFactor'          => '1.3.6.1.4.1.34097.3.1.1.6',
    'State'                => '1.3.6.1.4.1.34097.3.1.1.7',
    'kWh'                  => '1.3.6.1.4.1.34097.3.1.1.8', #the important one
    'kWhTime'              => '1.3.6.1.4.1.34097.3.1.1.9',
    'temp'                 => '1.3.6.1.4.1.34097.4',
    'tempTable'            => '1.3.6.1.4.1.34097.4.1',
    'tempEntry'            => '1.3.6.1.4.1.34097.4.1.1',
    'TempNr'               => '1.3.6.1.4.1.34097.4.1.1.1',
    'Temperature'          => '1.3.6.1.4.1.34097.4.1.1.2',
    'MaxTemp'              => '1.3.6.1.4.1.34097.4.1.1.3',
    'MaxTempTime'          => '1.3.6.1.4.1.34097.4.1.1.4',
    'TempWarning'          => '1.3.6.1.4.1.34097.4.1.1.5',
);

sub checkdevtype
{
    shift->checkSnmpOID('product');
}

sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();

    my $info = $dd->retrieveSnmpOIDs( 'product',
                                      'name',
                                      'version',
                                      'date',
                                    );


    $data->{'param'}{'comment'} = join(' ', map $info->{$_},
                                            qw( product name version )
                                       );

    $data->{'param'}{'legend'} = "Product: ". $info->{'product'}. ";\n".
                                 "Name:    ". $info->{'name'}. ";\n".
                                 "Version: ". $info->{'version'}. ";\n".
                                 "Date:    ". $info->{'date'}. ";";

    return 1;
}

sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    $cb->addTemplateApplication( $devNode, 'Ractivity::PDU');

}

1;

