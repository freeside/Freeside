#
#  Discovery module for Cisco Service Control Engine (formely PCube)
#
#  Copyright (C) 2007 Jon Nistor
#  Copyright (C) 2007 Stanislav Sinyagin
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

# $Id: CiscoSCE.pm,v 1.1 2010-12-27 00:03:56 ivan Exp $
# Jon Nistor <nistor at snickers dot org>
#
# NOTE: Options for this module
#       CiscoSCE::disable-disk
#       CiscoSCE::disable-gc
#       CiscoSCE::disable-qos
#       CiscoSCE::disable-rdr
#       CiscoSCE::disable-subs
#       CiscoSCE::disable-tp
#

# Cisco SCE devices discovery
package Torrus::DevDiscover::CiscoSCE;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'CiscoSCE'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
};

# pmodule-dependend OIDs are presented for module #1 only.
# currently devices with more than one module do not exist

our %oiddef =
    (
     # PCUBE-SE-MIB
     'pcubeProducts'        => '1.3.6.1.4.1.5655.1',
     'pchassisSysType'      => '1.3.6.1.4.1.5655.4.1.2.1.0',
     'pchassisNumSlots'     => '1.3.6.1.4.1.5655.4.1.2.6.0',
     'pmoduleType'          => '1.3.6.1.4.1.5655.4.1.3.1.1.2.1',
     'pmoduleNumLinks'      => '1.3.6.1.4.1.5655.4.1.3.1.1.7.1',
     'pmoduleSerialNumber'  => '1.3.6.1.4.1.5655.4.1.3.1.1.9.1',
     'pmoduleNumTrafficProcessors'   => '1.3.6.1.4.1.5655.4.1.3.1.1.3.1',
     'rdrFormatterEnable'            => '1.3.6.1.4.1.5655.4.1.6.1.0',
     'rdrFormatterCategoryName'      => '1.3.6.1.4.1.5655.4.1.6.11.1.2',
     'subscribersNumIpAddrMappings'  => '1.3.6.1.4.1.5655.4.1.8.1.1.3.1',
     'subscribersNumIpRangeMappings' => '1.3.6.1.4.1.5655.4.1.8.1.1.5.1',
     'subscribersNumVlanMappings'    => '1.3.6.1.4.1.5655.4.1.8.1.1.7.1',
     'subscribersNumAnonymous'       => '1.3.6.1.4.1.5655.4.1.8.1.1.16.1',
     'pportNumTxQueues'     => '1.3.6.1.4.1.5655.4.1.10.1.1.4.1',
     'pportIfIndex'         => '1.3.6.1.4.1.5655.4.1.10.1.1.5.1',
     'txQueuesDescription'  => '1.3.6.1.4.1.5655.4.1.11.1.1.4.1',

     # CISCO-SCAS-BB-MIB (PCUBE-ENGAGE-MIB)
     'globalScopeServiceCounterName' => '1.3.6.1.4.1.5655.4.2.5.1.1.3.1',
     
    );

our %sceChassisNames =
    (
     '1'    => 'unknown',
     '2'    => 'SE 1000',
     '3'    => 'SE 100',
     '4'    => 'SE 2000',
    );

our %sceModuleDesc =
    (
     '1'    => 'unknown',
     '2'    => '2xGBE + 1xFE Mgmt',
     '3'    => '2xFE + 1xFE Mgmt',
     '4'    => '4xGBE + 1 or 2 FastE Mgmt',
     '5'    => '4xFE + 1xFE Mgmt',
     '6'    => '4xOC-12 + 1 or 2 FastE Mgmt',
     '7'    => '16xFE + 2xGBE, 2 FastE Mgmt',
    );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'pcubeProducts',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
    {
        return 0;
    }
    
    my $result = $dd->retrieveSnmpOIDs('pchassisNumSlots');
    if( $result->{'pchassisNumSlots'} > 1 )
    {
        Error('This SCE device has more than one module on the chassis.' .
              'The current version of DevDiscover does not support such ' .
              'devices');
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

    # Get the system info and display it in the comment
    my $sceInfo = $dd->retrieveSnmpOIDs
        ( 'pchassisSysType', 'pmoduleType', 'pmoduleNumLinks',
          'pmoduleSerialNumber', 'pmoduleNumTrafficProcessors',
          'rdrFormatterEnable',
          'subscribersNumIpAddrMappings', 'subscribersNumIpRangeMappings',
          'subscribersNumVlanMappings', 'subscribersNumAnonymous' );

    $data->{'sceInfo'} = $sceInfo;
    
    $data->{'param'}{'comment'} =
        $sceChassisNames{$sceInfo->{'pchassisSysType'}} .
        " chassis, " . $sceModuleDesc{$sceInfo->{'pmoduleType'}} .
        ", Hw Serial#: " . $sceInfo->{'pmoduleSerialNumber'};
    
    # TP: Traffic Processor
    if( $devdetails->param('CiscoSCE::disable-tp') ne 'yes' )
    { 
        $devdetails->setCap('sceTP');

        $data->{'sceTrafficProcessors'} =
            $sceInfo->{'pmoduleNumTrafficProcessors'};
    }

    # HDD: Disk Usage
    if( $devdetails->param('CiscoSCE::disable-disk') ne 'yes' )
    {
        $devdetails->setCap('sceDisk');
    }

    # SUBS: subscriber aware configuration
    if( $devdetails->param('CiscoSCE::disable-subs') ne 'yes' )
    {
        if( $sceInfo->{'subscribersNumIpAddrMappings'}  > 0 or
            $sceInfo->{'subscribersNumIpRangeMappings'} > 0 or
            $sceInfo->{'subscribersNumVlanMappings'}    > 0 or
            $sceInfo->{'subscribersNumAnonymous'}       > 0 )
        {
            $devdetails->setCap('sceSubscribers');
        }
    }
    
    
    # QOS: TX Queues Names
    if( $devdetails->param('CiscoSCE::disable-qos') ne 'yes' )
    { 
        $devdetails->setCap('sceQos');

        # Get the names of TX queues
        my $txQueueNum = $session->get_table
            ( -baseoid => $dd->oiddef('pportNumTxQueues') );
        $devdetails->storeSnmpVars( $txQueueNum );
        
        my $ifIndexTable = $session->get_table
            ( -baseoid => $dd->oiddef('pportIfIndex') );

        my $txQueueDesc = $session->get_table
            ( -baseoid => $dd->oiddef('txQueuesDescription') );
        
        $devdetails->storeSnmpVars( $txQueueDesc );
        
        foreach my $pIndex
            ( $devdetails->getSnmpIndices( $dd->oiddef('pportNumTxQueues') ) )
        {
            # We take ports with more than one queue and add queueing
            # statistics to interface counters
            if( $txQueueNum->{$dd->oiddef('pportNumTxQueues') .
                                  '.' . $pIndex} > 1 )
            {
                # We need the ifIndex to retrieve the interface name
                
                my $ifIndex =
                    $ifIndexTable->{$dd->oiddef('pportIfIndex') . '.'
                                        . $pIndex};

                $data->{'scePortIfIndex'}{$pIndex} = $ifIndex;
                
                foreach my $qIndex
                    ( $devdetails->getSnmpIndices
                      ( $dd->oiddef('txQueuesDescription') . '.' . $pIndex ) )
                {
                    my $oid = $dd->oiddef('txQueuesDescription') . '.' .
                        $pIndex . '.' . $qIndex;
                    
                    $data->{'sceQueues'}{$pIndex}{$qIndex} =
                        $txQueueDesc->{$oid};
                }
            }
        }
    }


    # GC: Global Service Counters
    if( $devdetails->param('CiscoSCE::disable-gc') ne 'yes' )
    {
        # Set the Capability for the Global Counters
        $devdetails->setCap('sceGlobalCounters');

        my $counterNames = $session->get_table
            ( -baseoid => $dd->oiddef('globalScopeServiceCounterName') );
        
        $devdetails->storeSnmpVars( $counterNames );
        
        foreach my $gcIndex
            ( $devdetails->getSnmpIndices
              ( $dd->oiddef('globalScopeServiceCounterName') ) )
        {
            my $oid =
                $dd->oiddef('globalScopeServiceCounterName') . '.' . $gcIndex;
            if( length( $counterNames->{$oid} ) > 0 )
            {
                $data->{'sceGlobalCounters'}{$gcIndex} = $counterNames->{$oid};
            }
        }
    }


    # RDR: Raw Data Record
    if( $devdetails->param('CiscoSCE::disable-rdr') ne 'yes' )
    {   
        if( $sceInfo->{'rdrFormatterEnable'} > 0 )
        {
            # Set Capability for the RDR section of XML
            $devdetails->setCap('sceRDR');
            
            # Get the names of the RDR Category
            my $categoryNames = $session->get_table
                ( -baseoid => $dd->oiddef('rdrFormatterCategoryName') );
            
            $devdetails->storeSnmpVars( $categoryNames );
            
            foreach my $categoryIndex
                ( $devdetails->getSnmpIndices
                  ( $dd->oiddef('rdrFormatterCategoryName') ) )
            {
                my $oid = $dd->oiddef('rdrFormatterCategoryName') . '.'
                    . $categoryIndex;
                $data->{'sceRDR'}{$categoryIndex} = $categoryNames->{$oid};
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

    # Disk Usage information
    if( $devdetails->hasCap('sceDisk') )
    {
        $cb->addTemplateApplication($devNode, 'CiscoSCE::cisco-sce-disk');
    }

    if( $devdetails->hasCap('sceSubscribers') )
    {
        $cb->addTemplateApplication($devNode,
                                    'CiscoSCE::cisco-sce-subscribers');
    }

    # Traffic processors subtree
    if( $devdetails->hasCap('sceTP') )
    {   
        my $tpNode = $cb->addSubtree( $devNode, 'SCE_TrafficProcessors',
                                      { 'comment' => 'TP usage statistics' },
                                      [ 'CiscoSCE::cisco-sce-tp-subtree']);

        foreach my $tp ( 1 .. $data->{'sceTrafficProcessors'} )
        {
            $cb->addSubtree( $tpNode, sprintf('TP_%d', $tp),
                             { 'sce-tp-index' => $tp },
                             ['CiscoSCE::cisco-sce-tp'] );
        }
    }


    # QoS queues
    if( $devdetails->hasCap('sceQos') )
    { 
        # Queues subtree
        my $qNode =
            $cb->addSubtree( $devNode, 'SCE_Queues',
                             { 'comment' => 'TX queues usage statistics' },
                             [ 'CiscoSCE::cisco-sce-queues-subtree']);
        
        foreach my $pIndex ( sort {$a <=> $b}
                             keys %{$data->{'scePortIfIndex'}} )
        {
            my $ifIndex = $data->{'scePortIfIndex'}{$pIndex};
            my $interface = $data->{'interfaces'}{$ifIndex};

            my $portNode =
                $cb->addSubtree
                ( $qNode,
                  $interface->{$data->{'nameref'}{'ifSubtreeName'}},
                  { 'sce-port-index' => $pIndex,
                    'precedence' => 1000 - $pIndex });
            
            foreach my $qIndex ( sort {$a <=> $b} keys 
                                 %{$data->{'sceQueues'}{$pIndex}} )
            {
                my $qName = $data->{'sceQueues'}{$pIndex}{$qIndex};
                my $subtreeName = 'Q' . $qIndex;
                
                $cb->addLeaf( $portNode, $subtreeName,
                              { 'sce-queue-index' => $qIndex,
                                'comment' => $qName,
                                'precedence' => 1000 - $qIndex });
            }
        }
    } # hasCap sceQos


    # Global counters
    if( $devdetails->hasCap('sceGlobalCounters') )
    {
        foreach my $linkIndex ( 1 .. $data->{'sceInfo'}{'pmoduleNumLinks'} )
        {
            my $gcNode =
                $cb->addSubtree( $devNode,
                                 'SCE_Global_Counters_L' . $linkIndex,
                                 { 'comment' =>
                                       'Global service counters for link #'
                                       . $linkIndex
                                 },
                                 [ 'CiscoSCE::cisco-sce-gc-subtree']);
            
            foreach my $gcIndex
                ( sort {$a <=> $b} keys %{$data->{'sceGlobalCounters'}} )
            {
                my $srvName = $data->{'sceGlobalCounters'}{$gcIndex};
                my $subtreeName = $srvName;
                $subtreeName =~ s/\W/_/g;
                
                $cb->addSubtree( $gcNode, $subtreeName,
                                 { 'sce-link-index'   => $linkIndex,
                                   'sce-gc-index'     => $gcIndex,
                                   'comment'          => $srvName,
                                   'sce-service-name' => $srvName,
                                   'precedence'       => 1000 - $gcIndex,
                                   'searchable'       => 'yes'},
                                 [ 'CiscoSCE::cisco-sce-gcounter' ]);
            }
        }
    } # END hasCap sceGlobalCounters


    # RDR Formatter reports
    if( $devdetails->hasCap('sceRDR') )
    {
        $cb->addTemplateApplication($devNode, 'CiscoSCE::cisco-sce-rdr');

        # Add a Subtree for "SCE_RDR_Categories"
        my $rdrNode =
            $cb->addSubtree( $devNode, 'SCE_RDR_Categories',
                             { 'comment' => 'Raw Data Records per Category' },
                             [ 'CiscoSCE::cisco-sce-rdr-category-subtree' ]);
        
        foreach my $cIndex ( sort {$a <=> $b} keys %{$data->{'sceRDR'}} )
        {
            my $categoryName;
            if ( $data->{'sceRDR'}{$cIndex} )
            {
                $categoryName = $data->{'sceRDR'}{$cIndex};
            }
            else
            {
                $categoryName = 'Category_' . $cIndex;
            }
            
            $cb->addSubtree( $rdrNode, 'Category_' . $cIndex,
                             { 'precedence'      => 1000 - $cIndex,
                               'sce-rdr-index'   => $cIndex,
                               'sce-rdr-comment' => $categoryName },
                             ['CiscoSCE::cisco-sce-rdr-category'] );
        }
    } # END hasCap sceRDR    
}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
