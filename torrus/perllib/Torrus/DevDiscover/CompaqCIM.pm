#  Copyright (C) 2003  Shawn Ferry
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

# $Id: CompaqCIM.pm,v 1.1 2010-12-27 00:03:47 ivan Exp $
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>

# Compaq Insight Manager
# MIB files available at
# http://h18023.www1.hp.com/support/files/server/us/download/19885.html

package Torrus::DevDiscover::CompaqCIM;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'CompaqCIM'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

our %oiddef =
    (
     # Compaq Insite Manager
     'cpqcim'                           => '1.3.6.1.4.1.232',

     # CPQHLTH-MIB
     'cpqHeTemperatureTable'            => '1.3.6.1.4.1.232.6.2.6.8',
     'cpqHeTemperatureChassis'          => '1.3.6.1.4.1.232.6.2.6.8.1.1',
     'cpqHeTemperatureIndex'            => '1.3.6.1.4.1.232.6.2.6.8.1.2',
     'cpqHeTemperatureLocale'           => '1.3.6.1.4.1.232.6.2.6.8.1.3',
     'cpqHeTemperatureCelsius'          => '1.3.6.1.4.1.232.6.2.6.8.1.4',
     'cpqHeTemperatureHwLocation'       => '1.3.6.1.4.1.232.6.2.6.8.1.8',

     'cpqHeCorrMemTotalErrs'            => '1.3.6.1.4.1.232.6.2.3.3.0',

     # This is not a complete implementation  of the HLTH MIB

     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    return $dd->checkSnmpTable( 'cpqcim' );
}

my $enumLocale = {
    1   => 'other',
    2   => 'unknown',
    3   => 'system',
    4   => 'systemBoard',
    5   => 'ioBoard',
    6   => 'cpu',
    7   => 'memory',
    8   => 'storage',
    9   => 'removableMedia',
    10  => 'powerSupply',
    11  => 'ambient',
    12  => 'chassis',
    13  => 'bridgeCard',
};


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    my @checkOids = ( 'cpqHeCorrMemTotalErrs' );

    foreach my $oid ( @checkOids )
    {
        if( $dd->checkSnmpOID($oid) )
        { 
            $devdetails->setCap( $oid );
        }
    }

    my $TemperatureTable =
        $session->get_table( -baseoid =>
                             $dd->oiddef('cpqHeTemperatureTable') );

    if( defined( $TemperatureTable ) )
    {
        $devdetails->storeSnmpVars( $TemperatureTable );
        $devdetails->setCap( 'cpqHeTemperatureTable' );

        my $ref = {};
        $ref->{'indices'} = [];
        $data->{'TemperatureTable'} = $ref;

        # Index is Chassis . Index
        foreach my $INDEX
            ( $devdetails->
              getSnmpIndices( $dd->oiddef('cpqHeTemperatureIndex') ) )
        {
            next if ( $devdetails->snmpVar
                      ( $dd->oiddef('cpqHeTemperatureCelsius') .
                        '.' . $INDEX ) < 0 );

            push( @{$ref->{'indices'}}, $INDEX );

            my $chassis = $devdetails->snmpVar
                ( $dd->oiddef('cpqHeTemperatureChassis') . '.' . $INDEX );

            my $sensorIdx = $devdetails->snmpVar
                ( $dd->oiddef('cpqHeTemperatureIndex') . '.' . $INDEX );

            my $locale = $devdetails->snmpVar
                ( $dd->oiddef('cpqHeTemperatureLocale') . '.' . $INDEX );
            $locale = $enumLocale->{$locale} if $enumLocale->{$locale};

            my $location = $devdetails->snmpVar
                ( $dd->oiddef('cpqHeTemperatureHwLocation') . '.' . $INDEX );

            my $nick = sprintf('Chassis%d_%s_%d',
                               $chassis, $locale, $sensorIdx);

            my $param = {};
            $ref->{$INDEX}->{'param'} = $param;
            $param->{'cpq-cim-sensor-index'} = $INDEX;
            $param->{'cpq-cim-sensor-nick'} = $nick;
            $param->{'comment'} =
                sprintf('Chassis: %s Location: %s Index: %s',
                        $chassis, $locale, $sensorIdx);
            $param->{'precedence'} = 1000 - $sensorIdx;
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

    my $cimParam = {
        'comment'           => 'Compaq Insight Manager',
        'precedence'        => '-500',
    };

    my $cimNode = $cb->addSubtree( $devNode, 'CompaqCIM', $cimParam );

    my $healthParam = {
        'comment'           => 'Compaq CIM Health',
        'precedence'        => '-500'
        };

    my @healthTemplates;
    if( $devdetails->hasCap('cpqHeCorrMemTotalErrs') )
    {
        push( @healthTemplates, 'CompaqCIM::cpq-cim-corr-mem-errs' );
    }

    my $Health = $cb->addSubtree( $cimNode, 'Health', $healthParam,
                                  \@healthTemplates);

    if( $devdetails->hasCap('cpqHeTemperatureTable') )
    {
        my $tempParam = {
            'precedence' => '-100',
            'comment' => 'Compaq Temperature Sensors',
            'rrd-create-dstype' => 'GAUGE',
        };

        my $tempNode =
            $cb->addSubtree(  $Health, 'Temperature_Sensors', $tempParam );

        my $ref = $data->{'TemperatureTable'};

        foreach my $INDEX ( @{ $ref->{'indices'} } )
        {
            my $param = $ref->{$INDEX}->{'param'};
            $cb->addLeaf( $tempNode, $param->{'cpq-cim-sensor-nick'}, $param,
                          [ 'CompaqCIM::cpq-cim-temperature-sensor' ] );
        }
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
