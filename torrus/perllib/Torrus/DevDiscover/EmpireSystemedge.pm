#  Copyright (C) 2003 Shawn Ferry
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

# $Id: EmpireSystemedge.pm,v 1.1 2010-12-27 00:03:55 ivan Exp $
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>

package Torrus::DevDiscover::EmpireSystemedge;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'EmpireSystemedge'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


# define the oids that are needed to determine support,
# capabilities and information about the device
our %oiddef =
    (
     'empire'                   => '1.3.6.1.4.1.546',

     'sysedge_opmode'           => '1.3.6.1.4.1.546.1.1.1.17.0',
     'empireSystemType'         => '1.3.6.1.4.1.546.1.1.1.12.0',

     # Empire Cpu Table
     'empireCpuStatsTable'      => '1.3.6.1.4.1.546.13.1.1',
     'empireCpuStatsIndex'      => '1.3.6.1.4.1.546.13.1.1.1',
     'empireCpuStatsDescr'      => '1.3.6.1.4.1.546.13.1.1.2',

     # Empire Cpu Totals
     'empireCpuTotalWait'       => '1.3.6.1.4.1.546.13.5.0',

     # Empire Swap Counters
     'empireNumPageSwapIns'      => '1.3.6.1.4.1.546.1.1.7.8.18.0',

     # Empire Load Average
     'empireLoadAverage'        => '1.3.6.1.4.1.546.1.1.7.8.26.0',

     # Empire Device Table and Oids
     'empireDevTable'           => '1.3.6.1.4.1.546.1.1.1.7.1',
     'empireDevIndex'           => '1.3.6.1.4.1.546.1.1.1.7.1.1',
     'empireDevMntPt'           => '1.3.6.1.4.1.546.1.1.1.7.1.3',
     'empireDevBsize'           => '1.3.6.1.4.1.546.1.1.1.7.1.4',
     'empireDevTblks'           => '1.3.6.1.4.1.546.1.1.1.7.1.5',
     'empireDevType'            => '1.3.6.1.4.1.546.1.1.1.7.1.10',
     'empireDevDevice'          => '1.3.6.1.4.1.546.1.1.1.7.1.2',

     # Empire Device Stats Table and Oids
     'empireDiskStatsTable'      => '1.3.6.1.4.1.546.12.1.1',
     'empireDiskStatsIndex'      => '1.3.6.1.4.1.546.12.1.1.1',
     'empireDiskStatsHostIndex'  => '1.3.6.1.4.1.546.12.1.1.9',
     'hrDeviceDescr'             => '1.3.6.1.2.1.25.3.2.1.3',

     # Empire Performance and related oids
     'empirePerformance'        => '1.3.6.1.4.1.546.1.1.7',
     'empireNumTraps'           => '1.3.6.1.4.1.546.1.1.7.8.15.0',

     # Empire Process Stats
     'empireRunq'               => '1.3.6.1.4.1.546.1.1.7.8.4.0',
     'empireDiskWait'           => '1.3.6.1.4.1.546.1.1.7.8.5.0',
     'empirePageWait'           => '1.3.6.1.4.1.546.1.1.7.8.6.0',
     'empireSwapActive'         => '1.3.6.1.4.1.546.1.1.7.8.7.0',
     'empireSleepActive'        => '1.3.6.1.4.1.546.1.1.7.8.8.0',

     # Empire Extensions NTREGPERF
     'empireNTREGPERF'          => '1.3.6.1.4.1.546.5.7',

     'empireDnlc'               => '1.3.6.1.4.1.546.1.1.11',
     'empireRpc'                => '1.3.6.1.4.1.546.8.1',
     'empireNfs'                => '1.3.6.1.4.1.546.8.2',
     'empireMon'                => '1.3.6.1.4.1.546.6.1.1',
     'empirePmon'               => '1.3.6.1.4.1.546.15.1.1',
     'empireLog'                => '1.3.6.1.4.1.546.11.1.1',
     );

our %storageDescTranslate =  ( '/' => {'subtree' => 'root' } );

# template => 1 if specific templates for the name explicitly exist,
# othewise the template used is based on ident
#
# Generally only hosts that have been directly observed should have
# templates, the "unix" and "nt" templates are generally aiming for the
# lowest common denominator.
#
# templates also need to be added to devdiscover-config.pl
#
#    Templated "names" require a specific template for each of the
#    following base template types:
#    <template name="empire-swap-counters-NAME">
#    <template name="empire-counters-NAME">
#    <template name="empire-total-cpu-NAME">
#    <template name="empire-total-cpu-raw-NAME">
#    <template name="empire-cpu-NAME">
#    <template name="empire-cpu-raw-NAME">
#    <template name="empire-disk-stats-NAME">
#
#    i.e.
#    <template name="empire-swap-counters-solarisSparc">
#    <template name="empire-counters-solarisSparc">
#    <template name="empire-total-cpu-solarisSparc">
#    <template name="empire-total-cpu-raw-solarisSparc">
#    <template name="empire-cpu-solarisSparc">
#    <template name="empire-cpu-raw-solarisSparc">
#    <template name="empire-disk-stats-solarisSparc">
#


our %osTranslate =
    (
     1  => { 'name' => 'unknown',   'ident' => 'unknown', 'template' => 0, },
     2  => { 'name' => 'solarisSparc', 'ident' => 'unix', 'template' => 1, },
     3  => { 'name' => 'solarisIntel', 'ident' => 'unix', 'template' => 0, },
     4  => { 'name' => 'solarisPPC',   'ident' => 'unix', 'template' => 0, },
     5  => { 'name' => 'sunosSparc',   'ident' => 'unix', 'template' => 0, },
     6  => { 'name' => 'hpux9Parisc',  'ident' => 'unix', 'template' => 0, },
     7  => { 'name' => 'hpux10Parisc', 'ident' => 'unix', 'template' => 0, },
     8  => { 'name' => 'nt351Intel',   'ident' => 'nt',   'template' => 0, },
     9  => { 'name' => 'nt351Alpha',   'ident' => 'nt',   'template' => 0, },
     10 => { 'name' => 'nt40Intel',    'ident' => 'nt',   'template' => 1, },
     11 => { 'name' => 'nt40Alpha',    'ident' => 'nt',   'template' => 0, },
     12 => { 'name' => 'irix62Mips',   'ident' => 'unix', 'template' => 0, },
     13 => { 'name' => 'irix63Mips',   'ident' => 'unix', 'template' => 0, },
     14 => { 'name' => 'irix64Mips',   'ident' => 'unix', 'template' => 0, },
     15 => { 'name' => 'aix41RS6000',  'ident' => 'unix', 'template' => 0, },
     16 => { 'name' => 'aix42RS6000',  'ident' => 'unix', 'template' => 0, },
     17 => { 'name' => 'aix43RS6000',  'ident' => 'unix', 'template' => 0, },
     18 => { 'name' => 'irix65Mips',   'ident' => 'unix', 'template' => 0, },
     19 => { 'name' => 'digitalUNIX',  'ident' => 'unix', 'template' => 0, },
     20 => { 'name' => 'linuxIntel',   'ident' => 'unix', 'template' => 1, },
     21 => { 'name' => 'hpux11Parisc', 'ident' => 'unix', 'template' => 0, },
     22 => { 'name' => 'nt50Intel',    'ident' => 'nt',   'template' => 1, },
     23 => { 'name' => 'nt50Alpha',    'ident' => 'nt',   'template' => 0, },
     25 => { 'name' => 'aix5RS6000',   'ident' => 'unix', 'template' => 1, },
     26 => { 'name' => 'nt52Intel',    'ident' => 'nt',   'template' => 0, },
     );

# Solaris Virtual Interface Filtering
our $interfaceFilter;
my %solarisVirtualInterfaceFilter;

%solarisVirtualInterfaceFilter = (
    'Virtual Interface (iana 62)' => {
        'ifType'    =>  62,             # Obsoleted
        'ifDescr'   =>  '^\w+:\d+$',    # Virtual Interface in the form xxx:1
                                        # e.g. eri:1 eri1:2
        },

    'Virtual Interface' => {
        'ifType'    =>  6,
        'ifDescr'   =>  '^\w+:\d+$',    # Virtual Interface in the form xxx:1
                                        # e.g. eri:1 eri1:2
        },
    );

our $storageGraphTop;
our $storageHiMark;
our $shortTemplate;
our $longTemplate;

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    my $session = $dd->session();

    if( not $dd->checkSnmpTable( 'empire' ) )
    {
        return 0;
    }

    my $result = $dd->retrieveSnmpOIDs( 'sysedge_opmode',
                                        'empireSystemType' );
    if( $result->{'sysedge_opmode'} == 2 )
    {
        Error("Sysedge Agent NOT Licensed");
        $devdetails->setCap('SysedgeNotLicensed');
    }

    # Empire OS Type (Needed here for interface filtering)
    
    my $empireOsType = $result->{'empireSystemType'};
    if( defined($empireOsType) and $empireOsType > 0 )
    {
        $devdetails->setCap('EmpireSystemedge::' .
                            $osTranslate{$empireOsType}{ident} );
        
        $devdetails->{'os_ident'} = $osTranslate{$empireOsType}{ident};

        
        $devdetails->setCap('EmpireSystemedge::' .
                            $osTranslate{$empireOsType}{name} );
        
        $devdetails->{'os_name'} = $osTranslate{$empireOsType}{name};

        $devdetails->{'os_name_template'} =
            $osTranslate{$empireOsType}{template};
    }

    # Exclude Virtual Interfaces on Solaris
    if( $devdetails->{'os_name'} =~ /solaris/i ) {

        $interfaceFilter = \%solarisVirtualInterfaceFilter;
        &Torrus::DevDiscover::RFC2863_IF_MIB::addInterfaceFilter
            ($devdetails, $interfaceFilter);
    }

    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();
    my $session = $dd->session();


    if( $dd->checkSnmpOID('empireCpuTotalWait') )
    {
        $devdetails->setCap('EmpireSystemedge::CpuTotal::Wait');
    }

    # Empire Dev Stats Table

    my $empireDiskStatsTable =
        $session->get_table( -baseoid =>
                             $dd->oiddef('empireDiskStatsTable') );

    my $hrDeviceDescr = $session->get_table( -baseoid =>
                                             $dd->oiddef('hrDeviceDescr') );

    if( defined($empireDiskStatsTable) and defined($hrDeviceDescr) )
    {
        $devdetails->setCap('EmpireSystemedge::DiskStats');
        $devdetails->storeSnmpVars( $empireDiskStatsTable );
        $devdetails->storeSnmpVars( $hrDeviceDescr );

        my $ref= {'indices' => []};
        $data->{'empireDiskStats'} = $ref;

        foreach my $INDEX
            ( $devdetails->
              getSnmpIndices( $dd->oiddef('empireDiskStatsIndex') ) )
        {
            next if( $INDEX < 1 );

            my $hrindex =
                $devdetails->snmpVar( $dd->oiddef('empireDiskStatsHostIndex') .
                                      '.' . $INDEX );

            next if( $hrindex < 1 );

            push( @{ $ref->{'indices'} }, $INDEX );

            my $descr = $devdetails->snmpVar($dd->oiddef('hrDeviceDescr') .
                                             '.' . $hrindex );

            my $ref = { 'param' => {}, 'templates' => [] };
            $data->{'empireDiskStats'}{$INDEX} = $ref;
            my $param = $ref->{'param'};


            $param->{'comment'} = $descr;

            $param->{'HRINDEX'} = $hrindex;

            if ( not defined $descr )
            {
                $descr = "Index $hrindex";
            }
            $param->{'disk-stats-description'} = $descr;

            $descr =~ s/^\///;
            $descr =~ s/\W/_/g;
            $param->{'disk-stats-nick'} = $descr;

        }
    } # end empireDiskStatsTable

    # Empire Dev Table

    my $empireDevTable = $session->get_table( -baseoid =>
                                              $dd->oiddef('empireDevTable') );

    if( defined( $empireDevTable ) )
    {

        $devdetails->setCap('EmpireSystemedge::Devices');
        $devdetails->storeSnmpVars( $empireDevTable );

        my $ref= {};
        $data->{'empireDev'} = $ref;

        foreach my $INDEX
            ( $devdetails->getSnmpIndices($dd->oiddef('empireDevIndex') ) )
        {
            next if( $INDEX < 1 );


            my $type = $devdetails->snmpVar( $dd->oiddef('empireDevType') .
                                             '.' . $INDEX );

            my $descr = $devdetails->snmpVar($dd->oiddef('empireDevMntPt') .
                                             '.' . $INDEX );

            my $bsize =  $devdetails->snmpVar($dd->oiddef('empireDevBsize') .
                                              '.' . $INDEX );

            # NFS has a block size of 0, it will be skipped
            if( $bsize and defined( $descr ) )
            {
                push( @{ $data->{'empireDev'}->{'indices'} }, $INDEX);

                my $ref = { 'param' => {}, 'templates' => [] };
                $data->{'empireDev'}{$INDEX} = $ref;
                my $param = $ref->{'param'};

                $param->{'storage-description'} = $descr;
                $param->{'storage-device'} =
                    $devdetails->snmpVar($dd->oiddef('empireDevDevice')
                                         . '.' . $INDEX );

                my $comment = $type;
                if( $descr =~ /^\// )
                {
                    $comment .= ' (' . $descr . ')';
                }
                $param->{'comment'} = $comment;

                if( $storageDescTranslate{$descr}{'subtree'} )
                {
                    $descr = $storageDescTranslate{$descr}{'subtree'};
                }
                $descr =~ s/^\///;
                $descr =~ s/\W/_/g;
                $param->{'storage-nick'} = $descr;

                my $units = $bsize;

                $param->{'collector-scale'} = sprintf('%d,*', $units);

                my $size =
                    $devdetails->snmpVar
                    ($dd->oiddef('empireDevTblks') . '.' . $INDEX);

                if( $size )
                {
                    if( $storageGraphTop > 0 )
                    {
                        $param->{'graph-upper-limit'} =
                            sprintf('%e',
                                    $units * $size * $storageGraphTop / 100 );
                    }

                    if( $storageHiMark > 0 )
                    {
                        $param->{'upper-limit'} =
                            sprintf('%e',
                                    $units * $size * $storageHiMark / 100 );
                    }
                }

            }
        }

        $devdetails->clearCap( 'hrStorage' );

    } # end empireDevTable


    # Empire Per - Cpu Table

    my $empireCpuStatsTable =
        $session->get_table( -baseoid =>
                             $dd->oiddef('empireCpuStatsTable') );

    if( defined( $empireCpuStatsTable ) )
    {
        $devdetails->setCap('EmpireSystemedge::CpuStats');
        $devdetails->storeSnmpVars( $empireCpuStatsTable );

        my $ref= {};
        $data->{'empireCpuStats'} = $ref;

        foreach my $INDEX
            ( $devdetails->
              getSnmpIndices( $dd->oiddef('empireCpuStatsIndex') ) )
        {
            next if( $INDEX < 1 );

            push( @{ $ref->{'indices'} }, $INDEX);

            my $descr =
                $devdetails->snmpVar( $dd->oiddef('empireCpuStatsDescr') .
                                      '.' . $INDEX );

            my $ref = { 'param' => {}, 'templates' => [] };
            $data->{'empireCpuStats'}{$INDEX} = $ref;
            my $param = $ref->{'param'};

            $param->{'cpu'} = 'CPU' . $INDEX;
            $param->{'descr'} = $descr;
            $param->{'INDEX'} = $INDEX;
            $param->{'comment'} = $descr . ' (' . 'CPU ' . $INDEX . ')';
        }
    }

    # Empire Load Average

    if( $dd->checkSnmpOID('empireLoadAverage') )
    {
        $devdetails->setCap('EmpireSystemedge::LoadAverage');
    }

    # Empire Swap Counters

    if( $dd->checkSnmpOID('empireNumPageSwapIns') )
    {
        $devdetails->setCap('EmpireSystemedge::SwapCounters');
    }

    # Empire Counter Traps

    if( $dd->checkSnmpOID('empireNumTraps') )
    {
        $devdetails->setCap('EmpireSystemedge::CounterTraps');
    }

    # Empire Performance

    my $empirePerformance =
        $session->get_table( -baseoid => $dd->oiddef('empirePerformance') );

    if( defined( $empirePerformance ) )
    {
        $devdetails->setCap('EmpireSystemedge::Performance');
        $devdetails->storeSnmpVars( $empirePerformance );

        if( defined $devdetails->snmpVar($dd->oiddef('empireRunq') ) )
        {
            $devdetails->setCap('EmpireSystemedge::RunQ');
        }

        if( defined $devdetails->snmpVar($dd->oiddef('empireDiskWait') ) )
        {
            $devdetails->setCap('EmpireSystemedge::DiskWait');
        }

        if( defined $devdetails->snmpVar($dd->oiddef('empirePageWait') ) )
        {
            $devdetails->setCap('EmpireSystemedge::PageWait');
        }

        if( defined $devdetails->snmpVar($dd->oiddef('empireSwapActive') ) )
        {
            $devdetails->setCap('EmpireSystemedge::SwapActive');
        }

        if( defined $devdetails->snmpVar($dd->oiddef('empireSleepActive') ) )
        {
            $devdetails->setCap('EmpireSystemedge::SleepActive');
        }
    }

    my $empireNTREGPERF =
        $session->get_table( -baseoid => $dd->oiddef('empireNTREGPERF') );
    if( defined $empireNTREGPERF )
    {
        $devdetails->setCap('empireNTREGPERF');
        $devdetails->storeSnmpVars( $empireNTREGPERF );

        my $ref = {};
        $data->{'empireNTREGPERF'} = $ref;
        foreach my $INDEX
            ( $devdetails->getSnmpIndices($dd->oiddef('empireNTREGPERF') ) )
        {
            # This is all configured on a per site basis.
            # The xml will be site specific
            push( @{ $ref->{'indices'} }, $INDEX);
            my $template = {};
            $Torrus::ConfigBuilder::templateRegistry->
            {'EmpireSystemedge::NTREGPERF_' . $INDEX} = $template;
            $template->{'name'}='EmpireSystemedge::NTREGPERF_' . $INDEX;
            $template->{'source'}='vendor/empire.systemedge.ntregperf.xml';

        }
    }

#NOT CONFIGURED## Empire DNLC
#NOT CONFIGURED#    my $empireDnlc = $session->get_table( -baseoid =>
#NOT CONFIGURED#        $dd->oiddef('empireDnlc') );
#NOT CONFIGURED#    if( defined $empirePerformance )
#NOT CONFIGURED#    {
#NOT CONFIGURED#        # don't do this until we use the data
#NOT CONFIGURED#        #$devdetails->setCap('empirednlc');
#NOT CONFIGURED#        #$devdetails->storeSnmpVars( $empireDnlc );
#NOT CONFIGURED#    }
#NOT CONFIGURED#
#NOT CONFIGURED## Empire RPC
#NOT CONFIGURED#    my $empireRpc = $session->get_table( -baseoid =>
#NOT CONFIGURED#        $dd->oiddef('empireRpc') );
#NOT CONFIGURED#    if( defined $empireRpc )
#NOT CONFIGURED#    {
#NOT CONFIGURED#        # don't do this until we use the data
#NOT CONFIGURED#        #$devdetails->setCap('empirerpc');
#NOT CONFIGURED#        #$devdetails->storeSnmpVars( $empireRpc );
#NOT CONFIGURED#    }
#NOT CONFIGURED#
#NOT CONFIGURED## Empire NFS
#NOT CONFIGURED#    my $empireNfs = $session->get_table( -baseoid =>
#NOT CONFIGURED#        $dd->oiddef('empireNfs') );
#NOT CONFIGURED#    if( defined $empireRpc )
#NOT CONFIGURED#    {
#NOT CONFIGURED#        # don't do this until we use the data
#NOT CONFIGURED#        #$devdetails->setCap('empirenfs');
#NOT CONFIGURED#        #$devdetails->storeSnmpVars( $empireNfs );
#NOT CONFIGURED#    }
#NOT CONFIGURED#
#NOT CONFIGURED## Empire Mon Entries
#NOT CONFIGURED#    my $empireMon = $session->get_table( -baseoid =>
#NOT CONFIGURED#        $dd->oiddef('empireMon') );
#NOT CONFIGURED#    if( ref( $empireMon ) )
#NOT CONFIGURED#    {
#NOT CONFIGURED#        # don't do this until we use the data
#NOT CONFIGURED#        #$devdetails->setCap('empiremon');
#NOT CONFIGURED#        #$devdetails->storeSnmpVars( $empireMon );
#NOT CONFIGURED#    }
#NOT CONFIGURED#
#NOT CONFIGURED## Empire Process Monitor Entries
#NOT CONFIGURED#    my $empirePmon = $session->get_table( -baseoid =>
#NOT CONFIGURED#        $dd->oiddef('empirePmon') );
#NOT CONFIGURED#    if( ref( $empirePmon ) )
#NOT CONFIGURED#    {
#NOT CONFIGURED#        # don't do this until we use the data
#NOT CONFIGURED#        #$devdetails->setCap('empirePmon');
#NOT CONFIGURED#        #$devdetails->storeSnmpVars( $empirePmon );
#NOT CONFIGURED#    }
#NOT CONFIGURED#
#NOT CONFIGURED## Empire Log Monitor Entries
#NOT CONFIGURED#    my $empireLog = $session->get_table( -baseoid =>
#NOT CONFIGURED#        $dd->oiddef('empireLog') );
#NOT CONFIGURED#    if( ref( $empireLog ) )
#NOT CONFIGURED#    {
#NOT CONFIGURED#        # don't do this until we use the data
#NOT CONFIGURED#        #$devdetails->setCap('empireLog');
#NOT CONFIGURED#        #$devdetails->storeSnmpVars( $empireLog );
#NOT CONFIGURED#    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    my $data = $devdetails->data();

    my $mononlyTree = "Mon_Only";
    my $monParam = {
        'precedence'    => '-100000',
        'comment'       => 'Place to Stash Monitoring Data ',
        'hidden'        => 'yes',
    };

    my $monNode = $cb->addSubtree( $devNode, $mononlyTree, $monParam );
    $cb->addTemplateApplication
        ( $monNode, 'EmpireSystemedge::sysedge_opmode' );

    if( $devdetails->hasCap('SysedgeNotLicensed') )
    {
        return 1;
    }

    my $os_target;
    if( $devdetails->{'os_name_template'} )
    {
        $os_target = $devdetails->{'os_name'};
    }
    else
    {
        $os_target = $devdetails->{'os_ident'};
        Warn("Using Generic OS Templates '$os_target' for os: "
             .  $devdetails->{'os_name'} );
    }

    my $subtreeName = "Storage";

    my $param = {
        'precedence'    => '-1000',
        'comment'       => 'Storage Information',
    };

    my $StorageNode = $cb->addSubtree( $devNode, $subtreeName, $param );

    # Empire Devices(Storage)
    if( $devdetails->hasCap('EmpireSystemedge::Devices') )
    {
        my $subtreeName = "VolumeInfo";

        my $param = {
            'precedence'    => '-1000',
            'comment'       => 'Physical/Logical Volume Information',
        };

        my $subtreeNode =
            $cb->addSubtree( $StorageNode, $subtreeName, $param,
                             [ 'EmpireSystemedge::empire-device-subtree' ] );

        foreach my $INDEX ( sort {$a<=>$b} @{$data->{'empireDev'}{'indices'}} )
        {
            my $ref = $data->{'empireDev'}{$INDEX};

            # Display in index order
            $ref->{'param'}->{'precedence'} = sprintf("%d", 2000 - $INDEX);

            $cb->addSubtree( $subtreeNode, $ref->{'param'}{'storage-nick'},
                             $ref->{'param'},
                             [ 'EmpireSystemedge::empire-device' ] );
        }
    }

    # Empire Device Stats
    if( $devdetails->hasCap('EmpireSystemedge::DiskStats') )
    {
        my $subtreeName = "DiskInfo";

        my $param = {
            'precedence'    => '-1000',
            'comment'       => 'Physical/Logical Disk Information',
        };

        my $subtreeNode =
            $cb->addSubtree( $StorageNode, $subtreeName, $param,
                             ['EmpireSystemedge::empire-disk-stats-subtree']);

        foreach my $INDEX
            ( sort {$a<=>$b} @{$data->{'empireDiskStats'}{'indices'}} )
        {
            my $ref = $data->{'empireDiskStats'}{$INDEX};
            # Display in index order
            $ref->{'param'}->{'precedence'} = sprintf("%d", 1000 - $INDEX);

            $cb->addSubtree( $subtreeNode, $ref->{'param'}{'disk-stats-nick'},
                             $ref->{'param'},
                             [ 'EmpireSystemedge::empire-disk-stats-' .
                               $os_target, ] );
        }
    }


    # Performance Subtree
    my $subtreeName= "System_Performance";

    my $param = {
        'precedence'     => '-900',
        'comment'        => 'System, CPU and memory statistics'
        };

    my @perfTemplates = ();

    # Empire Load Average
    if( $devdetails->hasCap('EmpireSystemedge::LoadAverage') )
    {
        push( @perfTemplates, 'EmpireSystemedge::empire-load' );
    }

    # Empire Performance
    if( $devdetails->hasCap('EmpireSystemedge::Performance') )
    {
        push( @perfTemplates, 'EmpireSystemedge::empire-memory' );
    }

    push( @perfTemplates,
          'EmpireSystemedge::empire-counters-' . $os_target,
          'EmpireSystemedge::empire-swap-counters-' . $os_target,
          'EmpireSystemedge::empire-total-cpu-' .  $os_target,
          'EmpireSystemedge::empire-total-cpu-raw-' .  $os_target,
          );

    if( $devdetails->hasCap('EmpireSystemedge::RunQ') )
    {
        push( @perfTemplates, 'EmpireSystemedge::empire-runq' );
    }

    if( $devdetails->hasCap('EmpireSystemedge::DiskWait') )
    {
        push( @perfTemplates, 'EmpireSystemedge::empire-diskwait' );
    }

    if( $devdetails->hasCap('EmpireSystemedge::PageWait') )
    {
        push( @perfTemplates, 'EmpireSystemedge::empire-pagewait' );
    }

    if( $devdetails->hasCap('EmpireSystemedge::SwapActive') )
    {
        push( @perfTemplates, 'EmpireSystemedge::empire-swapactive' );
    }

    if( $devdetails->hasCap('EmpireSystemedge::SleepActive') )
    {
        push( @perfTemplates, 'EmpireSystemedge::empire-sleepactive' );
    }

    my $PerformanceNode = $cb->addSubtree( $devNode, $subtreeName,
                                           $param, \@perfTemplates   );

    # Empire CPU Stats
    if( $devdetails->hasCap('EmpireSystemedge::CpuStats') )
    {
        my $ref = $data->{'empireCpuStats'};

        my $subtreeName = "CpuStats";

        my $param = {
            'precedence'    => '-1100',
            'comment'       => 'Per-CPU Statistics',
        };

        my $subtreeNode =
            $cb->addSubtree( $PerformanceNode, $subtreeName, $param,
                             [ 'EmpireSystemedge::empire-cpu-subtree' ] );

        foreach my $INDEX
            ( sort {$a<=>$b} @{$data->{'empireCpuStats'}{'indices'} } )
        {
            my $ref = $data->{'empireCpuStats'}{$INDEX};

            # Display in index order
            $ref->{'param'}->{'precedence'} = sprintf("%d", 1000 - $INDEX);

            $cb->addSubtree
                ( $subtreeNode, $ref->{'param'}{'cpu'},
                  $ref->{'param'},
                  ['EmpireSystemedge::empire-cpu-' . $os_target,
                   'EmpireSystemedge::empire-cpu-raw-' . $os_target],
                  );
        }
    }

    if( $devdetails->hasCap('empireNTREGPERF') )
    {
        Debug("NTREGPERF");
        my $ntregTree = "NT_REG_PERF";
        my $ntregParam = {
            'precedence'    => '-10000',
            'comment'       => 'NT Reg Perf',
        };
        my $ntregnode =
            $cb->addSubtree( $devNode, $ntregTree, $ntregParam );

        foreach my $INDEX
            ( sort {$a<=>$b} @{$data->{'empireNTREGPERF'}{'indices'} } )
        {
            my $ref = $data->{'empireNTREGPERF'}{$INDEX};
            $cb->addTemplateApplication
                ( $ntregnode, 'EmpireSystemedge::NTREGPERF_' . $INDEX );

        }

    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
