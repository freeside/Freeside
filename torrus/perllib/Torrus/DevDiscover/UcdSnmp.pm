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

# $Id: UcdSnmp.pm,v 1.1 2010-12-27 00:03:47 ivan Exp $
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>

# Ucd Snmp Discovery

package Torrus::DevDiscover::UcdSnmp;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'UcdSnmp'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

our %oiddef =
    (
     # ucd
     'ucd'                      => '1.3.6.1.4.1.2021',
     'net_snmp'                 => '1.3.6.1.4.1.8072',

     # We assume that if we have Avail we also have Total
     'ucd_memAvailSwap'         => '1.3.6.1.4.1.2021.4.4.0',
     'ucd_memAvailReal'         => '1.3.6.1.4.1.2021.4.6.0',

     # If we have in we assume out
     'ucd_ssSwapIn'             => '1.3.6.1.4.1.2021.11.3.0',

     # If we have User we assume System and Idle
     'ucd_ssCpuRawUser'         => '1.3.6.1.4.1.2021.11.50.0',
     'ucd_ssCpuRawNice'         => '1.3.6.1.4.1.2021.11.51.0',
     'ucd_ssCpuRawWait'         => '1.3.6.1.4.1.2021.11.54.0',
     'ucd_ssCpuRawKernel'       => '1.3.6.1.4.1.2021.11.55.0',
     'ucd_ssCpuRawInterrupts'   => '1.3.6.1.4.1.2021.11.56.0',
     'ucd_ssCpuRawSoftIRQ'      => '1.3.6.1.4.1.2021.11.61.0',

     # if we have Sent we assume Received
     'ucd_ssIORawSent'          => '1.3.6.1.4.1.2021.11.57.0',

     'ucd_ssRawInterrupts'      => '1.3.6.1.4.1.2021.11.59.0',
     'ucd_ssRawContexts'        => '1.3.6.1.4.1.2021.11.60.0',

     'ucd_laTable'              => '1.3.6.1.4.1.2021.10'
     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    my $sysObjectID = $devdetails->snmpVar( $dd->oiddef('sysObjectID') );
    
    if( not $dd->oidBaseMatch( 'ucd', $sysObjectID )
        and
        not $dd->oidBaseMatch( 'net_snmp', $sysObjectID ) )
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

    my @checkOids = (
                     'ucd_memAvailSwap',
                     'ucd_memAvailReal',
                     'ucd_ssSwapIn',
                     'ucd_ssCpuRawUser',
                     'ucd_ssCpuRawWait',
                     'ucd_ssCpuRawKernel',
                     'ucd_ssCpuRawInterrupts',
                     'ucd_ssCpuRawNice',
                     'ucd_ssCpuRawSoftIRQ',
                     'ucd_ssIORawSent',
                     'ucd_ssRawInterrupts',
                     );


    my $result = $dd->retrieveSnmpOIDs( @checkOids );
    if( defined( $result ) )
    {
        foreach my $oid ( @checkOids )
        {
            if( defined($result->{$oid}) and length($result->{$oid}) > 0 )
            {
                $devdetails->setCap($oid);
            }
        }
    }

    if( $dd->checkSnmpTable('ucd_laTable') )
    {
        $devdetails->setCap('ucd_laTable');
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my $data = $devdetails->data();

    # Hostresources MIB is optional in net-snmp. We try and use the same
    # subtree name for UCD and Hostresources statistics.
    
    my $subtreeName =
        $devdetails->param('RFC2790_HOST_RESOURCES::sysperf-subtree-name');
    if( not defined( $subtreeName ) )
    {
        $subtreeName = 'System_Performance';
        $devdetails->setParam
            ('RFC2790_HOST_RESOURCES::sysperf-subtree-name', $subtreeName);
    }

    my @templates;
    if( $devdetails->hasCap('ucd_ssIORawSent') )
    {
        push( @templates, 'UcdSnmp::ucdsnmp-blockio' );
    }

    if( $devdetails->hasCap('ucd_ssRawInterrupts') )
    {
        push( @templates,  'UcdSnmp::ucdsnmp-raw-interrupts' );
    }

    if( $devdetails->hasCap('ucd_laTable') )
    {
        push( @templates, 'UcdSnmp::ucdsnmp-load-average' );
    }

    if( $devdetails->hasCap('ucd_memAvailSwap') )
    {
        push( @templates, 'UcdSnmp::ucdsnmp-memory-swap' );
    }

    if( $devdetails->hasCap('ucd_memAvailReal') )
    {
        push( @templates, 'UcdSnmp::ucdsnmp-memory-real' );
    }

    my $cpuMultiParam;
    my @cpuMultiTemplates;

    if( $devdetails->hasCap('ucd_ssCpuRawUser') )
    {
        $cpuMultiParam = {
            'graph-lower-limit' => '0',
            'rrd-hwpredict'     => 'disabled',
            'vertical-label'    => 'Cpu Usage',
            'comment'           => 'Cpu Idle, Sys, User',
            'ds-names'          => 'idle,sys,user',
            'ds-type'           => 'rrd-multigraph'
            };

        push( @templates,
              'UcdSnmp::ucdsnmp-cpu-user',
              'UcdSnmp::ucdsnmp-cpu-system',
              'UcdSnmp::ucdsnmp-cpu-idle' );

        push( @cpuMultiTemplates,
              'UcdSnmp::ucdsnmp-cpu-user-multi',
              'UcdSnmp::ucdsnmp-cpu-system-multi',
              'UcdSnmp::ucdsnmp-cpu-idle-multi' );

        if( $devdetails->hasCap('ucd_ssCpuRawWait') )
        {
            push( @templates, 'UcdSnmp::ucdsnmp-cpu-wait' );
            push( @cpuMultiTemplates, 'UcdSnmp::ucdsnmp-cpu-wait-multi' );

            $cpuMultiParam->{'comment'}  .= ', Wait';
            $cpuMultiParam->{'ds-names'} .= ',wait';
        }

        if( $devdetails->hasCap('ucd_ssCpuRawKernel') )
        {
            push( @templates, 'UcdSnmp::ucdsnmp-cpu-kernel' );
            push( @cpuMultiTemplates, 'UcdSnmp::ucdsnmp-cpu-kernel-multi' );

            $cpuMultiParam->{'comment'}  .= ', Kernel';
            $cpuMultiParam->{'ds-names'} .= ',kernel';
        }

        if( $devdetails->hasCap('ucd_ssCpuRawNice') )
        {
            push( @templates, 'UcdSnmp::ucdsnmp-cpu-nice' );
            push( @cpuMultiTemplates, 'UcdSnmp::ucdsnmp-cpu-nice-multi' );

            $cpuMultiParam->{'comment'}  .= ', Nice';
            $cpuMultiParam->{'ds-names'} .= ',nice';
        }

        if( $devdetails->hasCap('ucd_ssCpuRawInterrupts') )
        {
            push( @templates, 'UcdSnmp::ucdsnmp-cpu-interrupts' );
            push( @cpuMultiTemplates,
                  'UcdSnmp::ucdsnmp-cpu-interrupts-multi' );

            $cpuMultiParam->{'comment'}  .= ', Interrupts';
            $cpuMultiParam->{'ds-names'} .= ',int';
        }

        if( $devdetails->hasCap('ucd_ssCpuRawSoftIRQ') )
        {
            push( @templates, 'UcdSnmp::ucdsnmp-cpu-softirq' );
            push( @cpuMultiTemplates,
                  'UcdSnmp::ucdsnmp-cpu-softirq-multi' );

            $cpuMultiParam->{'comment'}  .= ', SoftIRQs';
            $cpuMultiParam->{'ds-names'} .= ',softirq';
        }

        $cpuMultiParam->{'comment'} =~ s/\,\s+(\w+)$/ and $1/;
    }

    my $perfNode = $cb->addSubtree( $devNode, $subtreeName,
                                    undef, \@templates);

    if( $cpuMultiParam )
    {
        $cb->addLeaf( $perfNode, 'Cpu_Stats',
                      $cpuMultiParam, \@cpuMultiTemplates );
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
