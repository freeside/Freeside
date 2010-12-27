#  Copyright (C) 2002  Stanislav Sinyagin
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

# $Id: RFC2670_DOCS_IF.pm,v 1.1 2010-12-27 00:03:55 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# DOCSIS interface statistics

package Torrus::DevDiscover::RFC2670_DOCS_IF;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'RFC2670_DOCS_IF'} = {
    'sequence'     => 100,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


$Torrus::DevDiscover::RFC2863_IF_MIB::knownSelectorActions{
    'DocsisUpSNRMonitor'} = 'RFC2670_DOCS_IF';
$Torrus::DevDiscover::RFC2863_IF_MIB::knownSelectorActions{
    'DocsisUpSNRTokenset'} = 'RFC2670_DOCS_IF';

$Torrus::DevDiscover::RFC2863_IF_MIB::knownSelectorActions{
    'DocsisUpFECCorMonitor'} = 'RFC2670_DOCS_IF';
$Torrus::DevDiscover::RFC2863_IF_MIB::knownSelectorActions{
    'DocsisUpFECUncorMonitor'} = 'RFC2670_DOCS_IF';

$Torrus::DevDiscover::RFC2863_IF_MIB::knownSelectorActions{
    'DocsisDownUtilMonitor'} = 'RFC2670_DOCS_IF';


our %oiddef =
    (
     # DOCS-IF-MIB
     'docsIfDownstreamChannelTable' => '1.3.6.1.2.1.10.127.1.1.1',
     'docsIfCmtsDownChannelCounterTable' => '1.3.6.1.2.1.10.127.1.3.10',
     'docsIfSigQSignalNoise' => '1.3.6.1.2.1.10.127.1.1.4.1.5',
     );



sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    if( $dd->checkSnmpTable( 'docsIfDownstreamChannelTable' ) )
    {
        return 1;
    }

    return 0;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();
    my $session = $dd->session();

    if( $dd->checkSnmpTable( 'docsIfCmtsDownChannelCounterTable' ) )
    {
        $devdetails->setCap('docsDownstreamUtil');
    }

    my $snrTable =
        $session->get_table( -baseoid =>
                             $dd->oiddef('docsIfSigQSignalNoise') );
    if( defined( $snrTable ) )
    {
        $devdetails->storeSnmpVars( $snrTable );
    }
    
    $data->{'docsCableMaclayer'} = [];
    $data->{'docsCableDownstream'} = [];
    $data->{'docsCableUpstream'} = [];

    foreach my $ifIndex ( sort {$a<=>$b} keys %{$data->{'interfaces'}} )
    {
        my $interface = $data->{'interfaces'}{$ifIndex};
        my $ifType = $interface->{'ifType'};

        $interface->{'docsTemplates'} = [];
        $interface->{'docsParams'} = {};

        if( $devdetails->hasCap('interfaceIndexingPersistent') )
        {
            $interface->{'docsParams'}{'interface-index'} = $ifIndex;
        }
        
        if( $ifType == 127 )
        {
            push( @{$data->{'docsCableMaclayer'}}, $ifIndex );
        }
        elsif(  $ifType == 128 )
        {
            push( @{$data->{'docsCableDownstream'}}, $ifIndex );
            if( $devdetails->hasCap('docsDownstreamUtil') )
            {
                push( @{$interface->{'docsTemplates'}},
                      'RFC2670_DOCS_IF::docsis-downstream-util' );
            }
        }
        elsif( $ifType == 129 or $ifType == 205 )
        {
            if( $devdetails->hasOID( $dd->oiddef('docsIfSigQSignalNoise') .
                                     '.' . $ifIndex ) )
            {
                push( @{$data->{'docsCableUpstream'}}, $ifIndex );
                push( @{$interface->{'docsTemplates'}},
                      'RFC2670_DOCS_IF::docsis-upstream-stats' );
                
            }
        }
    }
    
    if( $devdetails->param('RFC2670_DOCS_IF::upstreams-only') eq 'yes' )
    {
        $data->{'docsCableMaclayer'} = [];
        $data->{'docsCableDownstream'} = [];
    }

    $data->{'docsConfig'} = {
        'docsCableMaclayer' => {
            'subtreeName' => 'Docsis_MAC_Layer',
            'nodeidCategory' => 'docsmac',
            'templates' => [],
            'param' => {
                'node-display-name' => 'DOCSIS MAC Layer',
            },            
        },
        'docsCableDownstream' => {
            'subtreeName' => 'Docsis_Downstream',
            'nodeidCategory' => 'docsds',
            'templates' => [],
            'param' => {
                'node-display-name' => 'DOCSIS Downstream',
            },            
        },
        'docsCableUpstream' => {
            'subtreeName' => 'Docsis_Upstream',
            'nodeidCategory' => 'docsus',
            'templates' => ['RFC2670_DOCS_IF::docsis-upstream-subtree'],
            'param' => {
                'node-display-name' => 'DOCSIS Upstream',
            },            
        },
    };

    if( $devdetails->hasCap('docsDownstreamUtil') )
    {
        push( @{$data->{'docsConfig'}{'docsCableDownstream'}{'templates'}},
              'RFC2670_DOCS_IF::docsis-downstream-subtree' );        
    }
    
    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my $data = $devdetails->data();

    foreach my $category ( sort keys %{$data->{'docsConfig'}} )
    {
        if( scalar( @{$data->{$category}} ) > 0 and
            scalar( @{$data->{'docsConfig'}{$category}{'templates'}} ) > 0 )
        {
            # Count non-excluded interfaces
            my $updatedInterfaceList = [];
            foreach my $ifIndex ( @{$data->{$category}} )
            {
                my $interface = $data->{'interfaces'}{$ifIndex};
                next if $interface->{'excluded'};
                push( @{$updatedInterfaceList}, $ifIndex );
            }
            $data->{$category} = $updatedInterfaceList;
            
            next if scalar( @{$data->{$category}} ) == 0;

            my $subtreeNode =
                $cb->addSubtree( $devNode,
                                 $data->{'docsConfig'}{$category}{
                                     'subtreeName'},
                                 $data->{'docsConfig'}{$category}{
                                     'param'},
                                 $data->{'docsConfig'}{$category}{
                                     'templates'});

            foreach my $ifIndex ( @{$data->{$category}} )
            {
                my $interface = $data->{'interfaces'}{$ifIndex};

                my $param = $interface->{'docsParams'};

                $param->{'searchable'} = 'yes';

                # Copy some parameters from IF-MIB discovery results
                
                foreach my $p ('interface-name', 'interface-nick',
                               'node-display-name', 'comment')
                {
                    $param->{$p} = $interface->{'param'}{$p};
                }
                
                $param->{'nodeid-docsif'} =
                    $data->{'docsConfig'}{$category}{'nodeidCategory'} .
                    '//%nodeid-device%//' .
                    $interface->{$data->{'nameref'}{'ifNodeid'}};
                
                $param->{'nodeid'} = '%nodeid-docsif%';
                
                my $intfNode = $cb->addSubtree
                    ( $subtreeNode,
                      $interface->{$data->{'nameref'}{'ifSubtreeName'}},
                      $param, 
                      $interface->{'docsTemplates'} );

                # Apply selector actions
                if( $category eq 'docsCableUpstream' )
                {
                    my $monitor =
                        $interface->{'selectorActions'}{'DocsisUpSNRMonitor'};
                    my $tset =
                        $interface->{'selectorActions'}{'DocsisUpSNRTokenset'};
                    if( defined( $monitor ) or defined( $tset ) )
                    {
                        my $param = {};
                        if( defined( $monitor ) )
                        {
                            $param->{'monitor'} = $monitor;
                        }
                        if( defined( $tset ) )
                        {
                            $param->{'tokenset-member'} = $tset;
                        }
                        $cb->addLeaf( $intfNode, 'SNR', $param );
                    }

                    $monitor = $interface->{'selectorActions'}{
                        'DocsisUpFECCorMonitor'};
                    if( defined( $monitor ) )
                    {
                        $cb->addLeaf( $intfNode, 'Correctable',
                                      {'monitor' => $monitor } );
                    }

                    $monitor = $interface->{'selectorActions'}{
                        'DocsisUpFECUncorMonitor'};
                    if( defined( $monitor ) )
                    {
                        $cb->addLeaf( $intfNode, 'Uncorrectable',
                                      {'monitor' => $monitor } );
                    }                                        
                }
                elsif( $category eq 'docsCableDownstream')
                {
                    my $monitor = $interface->{'selectorActions'}{
                        'DocsisDownUtilMonitor'};
                    if( defined( $monitor ) )
                    {
                        $cb->addLeaf( $intfNode, 'UsedBytes',
                                      {'monitor' => $monitor } );
                    }
                }
            }
        }
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
