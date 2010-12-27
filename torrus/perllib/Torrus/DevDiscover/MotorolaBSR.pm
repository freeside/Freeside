#
#  Discovery module for Motorola Broadband Services Router (formely Riverdelta)
#
#  Copyright (C) 2006 Stanislav Sinyagin
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

# $Id: MotorolaBSR.pm,v 1.1 2010-12-27 00:03:53 ivan Exp $
#


# Cisco SCE devices discovery
package Torrus::DevDiscover::MotorolaBSR;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'MotorolaBSR'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

# pmodule-dependend OIDs are presented for module #1 only.
# currently devices with more than one module do not exist

our %oiddef =
    (
     'rdnProducts' => '1.3.6.1.4.1.4981.4.1',
     # RDN-CMTS-MIB
     'rdnCmtsUpstreamChannelTable' => '1.3.6.1.4.1.4981.2.1.2'     
     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'rdnProducts',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) or
        not $devdetails->isDevType('RFC2670_DOCS_IF') )
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

    my $session = $dd->session();
    my $data = $devdetails->data();

    $data->{'param'}{'ifindex-map'} = '$IFIDX_IFINDEX';
    Torrus::DevDiscover::RFC2863_IF_MIB::storeIfIndexParams( $devdetails );
    
    if( $dd->checkSnmpTable( 'rdnCmtsUpstreamChannelTable' ) )
    {
        $devdetails->setCap('rdnCmtsUpstreamChannelTable');

        foreach my $ifIndex ( @{$data->{'docsCableUpstream'}} )
        {
            my $interface = $data->{'interfaces'}{$ifIndex};
            
            push( @{$interface->{'docsTemplates'}},
                  'MotorolaBSR::motorola-bsr-docsis-upstream-util' );
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

    if( $devdetails->hasCap('rdnCmtsUpstreamChannelTable') and
        scalar( @{$data->{'docsCableUpstream'}} ) > 0 )
    {
        my $upstrNode =
            $cb->getChildSubtree( $devNode,
                                  $data->{'docsConfig'}{'docsCableUpstream'}{
                                      'subtreeName'} );
        
        my $shortcuts = 'snr,fec,freq,modems';
        
        my $param = {        
            'overview-shortcuts' =>
                $shortcuts,
                
                'overview-subleave-name-modems' => 'Modems',
                'overview-direct-link-modems' => 'yes',
                'overview-direct-link-view-modems' => 'expanded-dir-html',
                'overview-shortcut-text-modems' => 'All modems',
                'overview-shortcut-title-modems'=>
                'Show modem quantities in one page',
                'overview-page-title-modems' => 'Modem quantities',
            };

        $cb->addParams( $upstrNode, $param );
        
        # Build All_Modems summary graph
        
        my $param = {
            'ds-type'              => 'rrd-multigraph',
            'ds-names'             => 'registered,unregistered,offline',
            'graph-lower-limit'    => '0',
            'precedence'           => '1000',
                
            'vertical-label'       => 'Modems',
            'descriptive-nickname'     => '%system-id%: All modems',
            
            'ds-expr-registered' => '{Modems_Registered}',
            'graph-legend-registered' => 'Registered',
            'line-style-registered' => 'AREA',
            'line-color-registered' => '##blue',
            'line-order-registered' => '1',
            
            'ds-expr-unregistered' => '{Modems_Unregistered}',
            'graph-legend-unregistered' => 'Unregistered',
            'line-style-unregistered' => 'STACK',
            'line-color-unregistered' => '##crimson',
            'line-order-unregistered' => '2',
            
            'ds-expr-offline' => '{Modems_Offline}',
            'graph-legend-offline' => 'Offline',
            'line-style-offline' => 'STACK',
            'line-color-offline' => '##silver',
            'line-order-offline' => '3',                
        };
        
        $param->{'comment'} =
            'Registered, Unregistered and Offline modems on CMTS';
        
        $param->{'nodeid'} =
            $data->{'docsConfig'}{'docsCableUpstream'}{'nodeidCategory'} .
            '//%nodeid-device%//modems';
        
        my $first = 1;
        foreach my $ifIndex ( @{$data->{'docsCableUpstream'}} )
        {
            my $interface = $data->{'interfaces'}{$ifIndex};
            
            my $intf = $interface->{$data->{'nameref'}{'ifSubtreeName'}};
            
            if( $first )
            {
                $param->{'ds-expr-registered'} =
                    '{' . $intf . '/Modems_Registered}';
                $param->{'ds-expr-unregistered'} =
                    '{' . $intf . '/Modems_Unregistered}';
                $param->{'ds-expr-offline'} =
                    '{' . $intf . '/Modems_Offline}';
                $first = 0;
            }
            else
            {
                $param->{'ds-expr-registered'} .=
                    ',{' . $intf . '/Modems_Registered},+';
                $param->{'ds-expr-unregistered'} .=
                    ',{' . $intf . '/Modems_Unregistered},+';
                $param->{'ds-expr-offline'} .=
                    ',{' . $intf . '/Modems_Offline},+';
            }
        }

        my $usNode =
            $cb->getChildSubtree( $devNode,
                                  $data->{'docsConfig'}{
                                      'docsCableUpstream'}{
                                          'subtreeName'} );
        if( defined( $usNode ) )
        {
            $cb->addLeaf( $usNode, 'All_Modems', $param, [] );
        }
        else
        {
            Error('Could not find the Upstream subtree');
            exit 1;
        }
    }
}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
