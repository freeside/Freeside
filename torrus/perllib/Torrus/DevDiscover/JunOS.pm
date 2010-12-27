#
#  Copyright (C) 2007  Jon Nistor
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

# $Id: JunOS.pm,v 1.1 2010-12-27 00:03:53 ivan Exp $
# Jon Nistor <nistor at snickers.org>

# Juniper JunOS Discovery Module
#
# NOTE: For Class of service, if you are noticing that you are not seeing
#       all of your queue names show up, this is by design of Juniper.
#       Solution: Put place-holder names for those queues such as:
#                 "UNUSED-queue-#"
#       This is in reference to JunOS 7.6
#
# NOTE: Options for this module:
#       JunOS::disable-cos
#       JunOS::disable-cos-red
#       JunOS::disable-cos-tail
#       JunOS::disable-firewall
#       JunOS::disable-operating
#       JunOS::disable-rpf

package Torrus::DevDiscover::JunOS;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'JunOS'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
};


our %oiddef =
    (
     # JUNIPER-SMI
     'jnxProducts'          => '1.3.6.1.4.1.2636.1',
     'jnxBoxDescr'          => '1.3.6.1.4.1.2636.3.1.2.0',
     'jnxBoxSerialNo'       => '1.3.6.1.4.1.2636.3.1.3.0',

     # Operating status
     'jnxOperatingDescr'    => '1.3.6.1.4.1.2636.3.1.13.1.5',
     'jnxOperatingTemp'     => '1.3.6.1.4.1.2636.3.1.13.1.7',
     'jnxOperatingCPU'      => '1.3.6.1.4.1.2636.3.1.13.1.8',
     'jnxOperatingISR'      => '1.3.6.1.4.1.2636.3.1.13.1.9',
     'jnxOperatingDRAMSize' => '1.3.6.1.4.1.2636.3.1.13.1.10', # deprecated
     'jnxOperatingBuffer'   => '1.3.6.1.4.1.2636.3.1.13.1.11',
     'jnxOperatingMemory'   => '1.3.6.1.4.1.2636.3.1.13.1.15',

     # Firewall filter
     'jnxFWCounterDisplayFilterName' => '1.3.6.1.4.1.2636.3.5.2.1.6',
     'jnxFWCounterDisplayName'       => '1.3.6.1.4.1.2636.3.5.2.1.7',
     'jnxFWCounterDisplayType'       => '1.3.6.1.4.1.2636.3.5.2.1.8',

     # Class of Service (jnxCosIfqStatsTable deprecated, use jnxCosQstatTable)
     #             COS  - Class Of Service
     #             RED  - Random Early Detection
     #             PLP  - Packet Loss Priority
     #             DSCP - Differential Service Code Point

     'jnxCosFcIdToFcName'   => '1.3.6.1.4.1.2636.3.15.3.1.2',
     'jnxCosQstatQedPkts'   => '1.3.6.1.4.1.2636.3.15.4.1.3',

     # Reverse path forwarding
     'jnxRpfStatsPackets'   => '1.3.6.1.4.1.2636.3.17.1.1.1.3'

    );


# Not all interfaces are normally needed to monitor.
# You may override the interface filtering in devdiscover-siteconfig.pl:
# redefine $Torrus::DevDiscover::JunOS::interfaceFilter
# or define $Torrus::DevDiscover::JunOS::interfaceFilterOverlay

our $interfaceFilter;
our $interfaceFilterOverlay;
my %junosInterfaceFilter;

if( not defined( $interfaceFilter ) )
{
    $interfaceFilter = \%junosInterfaceFilter;
}


# Key is some unique symbolic name, does not mean anything
# ifType is the number to match the interface type
# ifDescr is the regexp to match the interface description
%junosInterfaceFilter =
    (
     'lsi' => {
         'ifType'  => 150,                   # mplsTunnel
         'ifDescr' => '^lsi$'
     },
     
     'other' => {
         'ifType'  => 1,                     # other
     },
     
     'loopback' => {
         'ifType'  => 24,                    # softwareLoopback
     },
     
     'propVirtual' => {
         'ifType'  => 53,                    # propVirtual
     },
     
     'gre_ipip_pime_pimd_mtun'  => {
         'ifType'  => 131,                     # tunnel
         'ifDescr' => '^(gre)|(ipip)|(pime)|(pimd)|(mtun)$'
     },

     'pd_pe_gr_ip_mt_lt' => {
         'ifType'  => 131,                     # tunnel
         'ifDescr' => '^(pd)|(pe)|(gr)|(ip)|(mt)|(lt)-\d+\/\d+\/\d+$'
     },
     
     'ls' => {
         'ifType'  => 108,                     # pppMultilinkBundle
         'ifDescr' => '^ls-\d+\/\d+\/\d+$'
     },
    );



sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'jnxProducts',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) )
        )
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
    my $chassisSerial =
        $dd->retrieveSnmpOIDs( 'jnxBoxDescr', 'jnxBoxSerialNo' );

    if( defined( $chassisSerial ) )
    {
        $data->{'param'}{'comment'} = $chassisSerial->{'jnxBoxDescr'} .
            ', Hw Serial#: ' . $chassisSerial->{'jnxBoxSerialNo'};
    } else
    {
        $data->{'param'}{'comment'} = "Juniper router";
    }


    # PROG: Class of Service
    #
    if( $devdetails->param('JunOS::disable-cos') ne 'yes' )
    {
        # Poll table to translate the CoS Index to a Name
        my $cosQueueNumTable =
            $session->get_table( -baseoid =>
                                 $dd->oiddef('jnxCosFcIdToFcName') );
        $devdetails->storeSnmpVars( $cosQueueNumTable );

        if( $cosQueueNumTable )
        {
            $devdetails->setCap('jnxCoS');

            # Find the index of the CoS queue name    
            foreach my $cosFcIndex ( $devdetails->getSnmpIndices
                                     ($dd->oiddef('jnxCosFcIdToFcName')) )
            {
                my $cosFcNameOid = $dd->oiddef('jnxCosFcIdToFcName') . "." .
                    $cosFcIndex;
                my $cosFcName    = $cosQueueNumTable->{$cosFcNameOid};

                Debug("JunOS::CoS  FC index: $cosFcIndex  name: $cosFcName");

                # Construct the data ...
                $data->{'jnxCos'}{'queue'}{$cosFcIndex} = $cosFcName;
            }

            # We need to find out all the interfaces that have CoS enabled
            # on them. We will use jnxCosQstatQedPkts as our reference point.
            my $cosIfIndex =
                $session->get_table( -baseoid =>
                                     $dd->oiddef('jnxCosQstatQedPkts') );
            $devdetails->storeSnmpVars( $cosIfIndex );

	    if( $cosIfIndex )            
            {
		foreach my $INDEX ( $devdetails->getSnmpIndices
                                ($dd->oiddef('jnxCosQstatQedPkts')) )
            	{
                	my( $ifIndex, $cosQueueIndex ) = split( '\.', $INDEX );
			$data->{'jnxCos'}{'ifIndex'}{$ifIndex} = 1;
               	} 
            }
        }
    } # END JunOS::disable-cos


    # PROG: Grab and store description of parts
    #
    if( $devdetails->param('JunOS::disable-operating') ne 'yes' )
    {
        my $tableDesc = $session->get_table( -baseoid =>
                                             $dd->oiddef('jnxOperatingDescr'));
        $devdetails->storeSnmpVars( $tableDesc );

        if ( $tableDesc )
        {
            # PROG: Set Capability flag
            $devdetails->setCap('jnxOperating');

            # PROG: Poll tables for more info to match and index on
            my $tableCPU =
                $session->get_table( -baseoid =>
                                     $dd->oiddef('jnxOperatingCPU'));
            $devdetails->storeSnmpVars( $tableCPU );

            my $tableISR =
                $session->get_table( -baseoid =>
                                     $dd->oiddef('jnxOperatingISR'));
            $devdetails->storeSnmpVars( $tableISR );

            my $tableMEM =
                $session->get_table( -baseoid =>
                                     $dd->oiddef('jnxOperatingMemory'));
            $devdetails->storeSnmpVars( $tableMEM );

            my $tableTemp =
                $session->get_table( -baseoid =>
                                     $dd->oiddef('jnxOperatingTemp'));
            $devdetails->storeSnmpVars( $tableTemp );

            # PROG: Build tables for all the oids
            #       We are using the Descr oid base for matching. (cheap hack)
            foreach my $opIndex ( $devdetails->getSnmpIndices
                                  ($dd->oiddef('jnxOperatingDescr')) )
            {
                my $opCPU  = $devdetails->snmpVar
                    ($dd->oiddef('jnxOperatingCPU') . '.' . $opIndex);
                my $opDesc = $devdetails->snmpVar
                    ($dd->oiddef('jnxOperatingDescr') . '.' . $opIndex);
                my $opMem  = $devdetails->snmpVar
                    ($dd->oiddef('jnxOperatingMemory') . '.' . $opIndex);
                my $opISR  = $devdetails->snmpVar
                    ($dd->oiddef('jnxOperatingISR') . '.' . $opIndex);
                my $opTemp = $devdetails->snmpVar
                    ($dd->oiddef('jnxOperatingTemp')  . '.' . $opIndex);

                Debug("JunOS:: opIdx: $opIndex  Desc: $opDesc");
                Debug("JunOS::   CPU: $opCPU, CPU: $opISR, MEM: $opMem");
                Debug("JunOS::   Temp: $opTemp");

                # Construct the data
                $data->{'jnxOperating'}{$opIndex}{'index'} = $opIndex;
                $data->{'jnxOperating'}{$opIndex}{'cpu'}   = $opCPU;
                $data->{'jnxOperating'}{$opIndex}{'desc'}  = $opDesc;
                $data->{'jnxOperating'}{$opIndex}{'isr'}   = $opISR;
                $data->{'jnxOperating'}{$opIndex}{'mem'}   = $opMem;
                $data->{'jnxOperating'}{$opIndex}{'temp'}  = $opTemp;
            }
        } # END: if $tableDesc
    } # END: JunOS::disable-operating


    # PROG: Firewall statistics
    if( $devdetails->param('JunOS::disable-firewall') ne 'yes' )
    {
        my $tableFWFilter =
            $session->get_table( -baseoid =>
                                 $dd->oiddef('jnxFWCounterDisplayFilterName'));
        $devdetails->storeSnmpVars( $tableFWFilter );

        if( $tableFWFilter )
        {
            # PROG: Set Capability flag
            $devdetails->setCap('jnxFirewall');

            # PROG: Poll tables for more info to match and index on
            my $tableFWCounter =
                $session->get_table( -baseoid =>
                                     $dd->oiddef('jnxFWCounterDisplayName') );
            $devdetails->storeSnmpVars( $tableFWCounter );

            # Firewall Type (counter = 2, policer = 3)
            my $tableFWType  =
                $session->get_table( -baseoid =>
                                     $dd->oiddef('jnxFWCounterDisplayType') );
            $devdetails->storeSnmpVars( $tableFWType );

            # PROG: Build tables for all the oids
            #       We are using the FW Filter name as the Indexing
            foreach my $fwIndex ( $devdetails->getSnmpIndices
                                  ($dd->oiddef('jnxFWCounterDisplayName')) )
            {
                my $fwFilter = $devdetails->snmpVar
                    ($dd->oiddef('jnxFWCounterDisplayFilterName') .
                     '.' . $fwIndex);
                my $fwCounter  = $devdetails->snmpVar
                    ($dd->oiddef('jnxFWCounterDisplayName') .
                     '.' . $fwIndex);
                my $fwType = $devdetails->snmpVar
                    ($dd->oiddef('jnxFWCounterDisplayType') .
                     '.' . $fwIndex);
                Debug("JunOS::fw Filter: $fwFilter");
                Debug("JunOS::fw         Counter: $fwCounter");
                Debug("JunOS::fw            Type: $fwType");

                # Construct the data
                $data->{'jnxFirewall'}{$fwFilter}{$fwCounter}{'oid'} =
                    $fwIndex;
                $data->{'jnxFirewall'}{$fwFilter}{$fwCounter}{'type'} =
                    $fwType;
            }
        } # END: if $tableFWfilter
    } # END: JunOS::diable-firewall


    # PROG: Check for RPF availability
    if( $devdetails->param('JunOS::disable-rpf') ne 'yes' )
    {
        my $tableRPF =
            $session->get_table( -baseoid =>
                                 $dd->oiddef('jnxRpfStatsPackets') );
        $devdetails->storeSnmpVars( $tableRPF );

        if( $tableRPF )
        {
            # PROG: Set capability flag
            $devdetails->setCap('jnxRPF');

            # PROG: Find all the relevent interfaces
            foreach my $rpfIndex ( $devdetails->getSnmpIndices
                                   ($dd->oiddef('jnxRpfStatsPackets')) )
            {
                my ($ifIndex,$addrFamily) = split('\.',$rpfIndex);
                if( defined( $data->{'interfaces'}{$ifIndex} ) )
                {
                    my $ifAddrFam = $addrFamily == 1 ? 'ipv4' : 'ipv6';
                    my $intName   = $data->{'interfaces'}{$ifIndex}{'ifName'};
                    my $intNameT  = $data->{'interfaces'}{$ifIndex}{'ifNameT'};
                    
                    # Construct data
                    $data->{'jnxRPF'}{$ifIndex}{'ifName'}  = $intName;
                    $data->{'jnxRPF'}{$ifIndex}{'ifNameT'} = $intNameT;
                    
                    if( $addrFamily == 1 )
                    {
                        $data->{'jnxRPF'}{$ifIndex}{'ipv4'} = 1;
                    }
                    if( $addrFamily == 2 )
                    {
                        $data->{'jnxRPF'}{$ifIndex}{'ipv6'} = 2;
                    }                    
                }
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


    # PROG: Class of Service information
    if( $devdetails->hasCap('jnxCoS') &&
	( keys %{$data->{'jnxCos'}{'ifIndex'}} > 0 )
       )
    {
	# PROG: Add CoS information if it exists.
	my $nodeTop = $cb->addSubtree( $devNode, 'CoS', undef,
                                  [ 'JunOS::junos-cos-subtree']);

        foreach my $ifIndex ( sort {$a <=> $b} keys
                              %{$data->{'jnxCos'}{'ifIndex'}} )
        {
            my $interface = $data->{'interfaces'}{$ifIndex};
            my $ifAlias   = $interface->{'ifAlias'};
            my $ifDescr   = $interface->{'ifDescr'};
            my $ifName    = $interface->{'ifNameT'};

            next if( not $ifName );  # Skip since port is likely 'disabled'
            # This might be better to match against ifType
            # as well since not all of them support Q's.

            # Add Subtree per port
            my $nodePort =
                $cb->addSubtree( $nodeTop, $ifName,
                                 { 'comment'    => $ifAlias,
                                   'precedence' => 1000 - $ifIndex },
                                 [ 'JunOS::junos-cos-subtree-interface' ]);

            # Loop to create subtree's for each QueueName/ID pair
            foreach my $cosIndex ( sort keys %{$data->{'jnxCos'}{'queue'}} )
            {
                my $cosName  = $data->{'jnxCos'}{'queue'}{$cosIndex};
                
                # Add Leaf for each one
                Debug("JunOS::CoS  ifIndex: $ifIndex ($ifName -> $cosName)");
                my $nodeIFCOS =
                    $cb->addSubtree( $nodePort, $cosName,
                                     { 'comment'    => "Class: " . $cosName,
                                       'cos-index'  => $cosIndex,
                                       'cos-name'   => $cosName,
                                       'ifDescr'    => $ifDescr,
                                       'ifIndex'    => $ifIndex,
                                       'ifName'     => $ifName,
                                       'precedence' => 1000 - $cosIndex },
                                     [ 'JunOS::junos-cos-leaf' ]);

                if( $devdetails->param('JunOS::disable-cos-tail') ne 'yes' )
                {
                    $cb->addSubtree( $nodeIFCOS, "Tail_drop_stats",
                                     { 'comment'  => 'Tail drop statistics' },
                                     [ 'JunOS::junos-cos-tail' ]);
                }

                if( $devdetails->param('JunOS::disable-cos-red') ne 'yes' )
                {
                    $cb->addSubtree
                        ( $nodeIFCOS, "RED_stats",
                          { 'comment'  => 'Random Early Detection' },
                          [ 'JunOS::junos-cos-red' ]);
                }
                
            } # end foreach (INDEX of queue's [Q-ID])
        } # end foreach (INDEX of port)
    } # end if HasCap->{CoS}


    # PROG: Firewall Table (filters and counters)
    if( $devdetails->hasCap('jnxFirewall') )
    {
        # Add subtree first
        my $nodeFW = $cb->addSubtree( $devNode, 'Firewall', undef,
                                      [ 'JunOS::junos-firewall-subtree' ]);

        # Loop through and find all the filter names
        foreach my $fwFilter
            ( sort {$a <=> $b} keys %{$data->{'jnxFirewall'}} )
        {
            my $firewall  = $data->{'jnxFirewall'}{$fwFilter};

            # Add subtree for FilterName
            my $nodeFWFilter =
                $cb->addSubtree( $nodeFW, $fwFilter,
                                 { 'comment' => 'Filter: ' . $fwFilter },
                                 [ 'JunOS::junos-firewall-filter-subtree' ]);
            
            # Loop through and find all the counter names within the filter
            foreach my $fwCounter ( sort {$a <=> $b} keys %{$firewall} )
            {
                my $fwOid     = $firewall->{$fwCounter}{'oid'};
                my $fwType    = $firewall->{$fwCounter}{'type'};
                my @templates = ( 'JunOS::junos-firewall-filter' );

                # Figure out which templates to apply ...
                if ($fwType == 2)
                {
                    # fwType is a counter ...
                    push( @templates,
                          'JunOS::junos-firewall-filter-counter',
                          'JunOS::junos-firewall-filter-policer' );
                }
                elsif ($fwType == 3)
                {
                    # fwType is a policer ...
                    push( @templates,
                          'JunOS::junos-firewall-filter-policer' );
                } # END: if $fwType

                # Finally, add the subtree...
                my $fwTypeName = $fwType == 2 ? 'Counter: ' : 'Policer: ';
                my $nodeFWCounter =
                    $cb->addSubtree($nodeFWFilter, $fwCounter,
                                    { 'comment'    => $fwTypeName . $fwCounter,
                                      'fw-counter' => $fwCounter,
                                      'fw-filter'  => $fwFilter,
                                      'fw-index'   => $fwOid }, \@templates );
            } # END foreach $fwCounter
        } # END foreach $fwFilter
    } # END: if hasCap jnxFirewall


    # PROG: Operating Status Table
    # NOTE: According to the Juniper MIB, the following is a statement:
    #       jnxOperatingTemp: The temperature in Celsius (degrees C) of this
    #                         subject.  Zero if unavailable or inapplicable.
    #       The same applies for all values under Operating status table, if
    #       Zero is shown it might be considered unavail or N/A.  We will
    #       also take that into consideration.
    # NOTE: Also so poorly written, its great.
    if( $devdetails->hasCap('jnxOperating') )
    {
        my $nodeCPU  = $cb->addSubtree( $devNode, 'CPU_Usage', undef,
                                        [ 'JunOS::junos-cpu-subtree' ]);

        my $nodeMem  = $cb->addSubtree( $devNode, 'Memory_Usage', undef,
                                        [ 'JunOS::junos-memory-subtree' ]);

        my $nodeTemp =
            $cb->addSubtree( $devNode, 'Temperature_Sensors', undef,
                             [ 'JunOS::junos-temperature-subtree' ]);

        
        foreach my $opIndex
            ( sort {$a <=> $b} keys %{$data->{'jnxOperating'}} )
        {
            my $operating = $data->{'jnxOperating'}{$opIndex};
            my $jnxCPU    = $operating->{'cpu'};
            my $jnxDesc   = $operating->{'desc'};
            my $jnxMem    = $operating->{'mem'};
            my $jnxTemp   = $operating->{'temp'};
            my $jnxTag = $jnxDesc;
            $jnxTag =~ s/\W+/_/go;
            $jnxTag =~ s/_$//go;
            # Fix the .'s into _'s for the RRD-DS and name of leaf
            my $opIndexFix = $opIndex;
            $opIndexFix =~ s/\./_/g;

            # PROG: Find CPU that does not equal 0
            if ($jnxCPU > 0)
            {
                $cb->addSubtree( $nodeCPU, $jnxTag,
                                 { 'comment'   => $jnxDesc,
                                   'cpu-index' => $opIndex },
                                 [ 'JunOS::junos-cpu' ]);
            }

            # PROG: Find memory that does not equal 0
            if ($jnxMem > 0)
            {
                $cb->addSubtree( $nodeMem, $jnxTag,
                                 { 'comment'      => $jnxDesc,
                                   'mem-index'    => $opIndex,
                                   'mem-indexFix' => $opIndexFix },
                                 [ 'JunOS::junos-memory' ]);
            }

            # PROG: Find Temperature that does not equal 0
            if ($jnxTemp > 0)
            {
                if ($jnxDesc =~ /(temp.* sensor|Engine)/) {
                    # Small little hack to cleanup the sensor tags
                    $jnxTag =~ s/_temp(erature|)_sensor//g;
                    $cb->addLeaf( $nodeTemp, $jnxTag,
                                  { 'comment'         => $jnxDesc,
                                    'sensor-desc'     => $jnxDesc, 
                                    'sensor-index'    => $opIndex,
                                    'sensor-indexFix' => $opIndexFix },
                                  [ 'JunOS::junos-temperature-sensor' ]);
                }
            }
        } # END foreach $opIndex
    } # END if jnxOperating


    # PROG: Reverse Forwarding Path (RPF)
    if( $devdetails->hasCap('jnxRPF') )
    {
        # Add subtree first
        my $nodeRPF = $cb->addSubtree( $devNode, 'RPF', undef,
                                       [ 'JunOS::junos-rpf-subtree' ]);

        # Loop through and find all interfaces with RPF enabled
        foreach my $ifIndex ( sort {$a <=> $b} keys %{$data->{'jnxRPF'}} )
        {
            # Set some names
            my $ifAlias = $data->{'interfaces'}{$ifIndex}{'ifAlias'};
            my $ifName  = $data->{'interfaces'}{$ifIndex}{'ifName'};
            my $ifNameT = $data->{'interfaces'}{$ifIndex}{'ifNameT'};
            my $hasIPv4 = $data->{'jnxRPF'}{$ifIndex}{'ipv4'};
            my $hasIPv6 = $data->{'jnxRPF'}{$ifIndex}{'ipv6'};

            Debug("JunOS:: RPF  int: $ifName  IPv4: $hasIPv4  IPv6: $hasIPv6");

            # PROG: Process IPv4 first ... 
            if( $hasIPv4 )
            {
                $cb->addSubtree( $nodeRPF, 'IPv4_' . $ifNameT,
                                 { 'comment'    => $ifAlias,
                                   'ifAddrType' => "ipv4",
                                   'ifName'     => $ifName,
                                   'ifNameT'    => $ifNameT,
                                   'rpfIndex'   => $ifIndex . "." . $hasIPv4 },
                                 [ 'JunOS::junos-rpf' ]);
            }

            if( $hasIPv6 )
            {
                $cb->addSubtree( $nodeRPF, 'IPv6_' . $ifNameT,
                                 { 'comment'    => $ifAlias,
                                   'ifAddrType' => "ipv6",
                                   'ifName'     => $ifName,
                                   'ifNameT'    => $ifNameT,
                                   'rpfIndex'   => $ifIndex . "." . $hasIPv6 },
                                 [ 'JunOS::junos-rpf' ]);
            }
        }
    } # END: if jnxRPF
}


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
