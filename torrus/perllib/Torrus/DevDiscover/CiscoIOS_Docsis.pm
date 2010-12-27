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

# $Id: CiscoIOS_Docsis.pm,v 1.1 2010-12-27 00:03:46 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# DOCSIS interface, Cisco specific

package Torrus::DevDiscover::CiscoIOS_Docsis;

use strict;
use Torrus::Log;

# Sequence number is 600 - we depend on RFC2670_DOCS_IF and CiscoIOS

$Torrus::DevDiscover::registry{'CiscoIOS_Docsis'} = {
    'sequence'     => 600,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

$Torrus::DevDiscover::RFC2863_IF_MIB::knownSelectorActions{
    'DocsisMacModemsMonitor'} = 'CiscoIOS_Docsis';

$Torrus::DevDiscover::RFC2863_IF_MIB::knownSelectorActions{
    'DocsisUpUtilMonitor'} = 'CiscoIOS_Docsis';
$Torrus::DevDiscover::RFC2863_IF_MIB::knownSelectorActions{
    'DocsisUpSlotsMonitor'} = 'CiscoIOS_Docsis';


our %oiddef =
    (
     # CISCO-DOCS-EXT-MIB:cdxIfUpstreamChannelExtTable
     'cdxIfUpChannelMaxUGSLastFiveMins' => '1.3.6.1.4.1.9.9.116.1.4.1.1.14'
     );


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( $devdetails->isDevType('CiscoIOS') and
        $devdetails->isDevType('RFC2670_DOCS_IF') )
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
    
    if( $dd->checkSnmpTable( 'cdxIfUpChannelMaxUGSLastFiveMins' ) )
    {
        $devdetails->setCap('cdxIfUpChannelMaxUGSLastFiveMins');
    }

    push( @{$data->{'docsConfig'}{'docsCableMaclayer'}{'templates'}},
          'CiscoIOS_Docsis::cisco-docsis-mac-subtree' );

    foreach my $ifIndex ( @{$data->{'docsCableMaclayer'}} )
    {
        my $interface = $data->{'interfaces'}{$ifIndex};

        push( @{$interface->{'docsTemplates'}},
              'CiscoIOS_Docsis::cisco-docsis-mac-util' );
    }

    foreach my $ifIndex ( @{$data->{'docsCableUpstream'}} )
    {
        my $interface = $data->{'interfaces'}{$ifIndex};

        push( @{$interface->{'docsTemplates'}},
              'CiscoIOS_Docsis::cisco-docsis-upstream-util' );
    }
    
    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my $data = $devdetails->data();

    if( $devdetails->hasCap('cdxIfUpChannelMaxUGSLastFiveMins') )
    {
        $cb->setVar( $devNode, 'CiscoIOS_Docsis::ugs-supported', 'true' );
    }

    if( scalar( @{$data->{'docsCableMaclayer'}} ) > 0 )
    {
        # Build All_Modems summary graph
        my $param = {
            'ds-type'              => 'rrd-multigraph',
            'ds-names'             => 'total,active,registered',
            'graph-lower-limit'    => '0',
            'precedence'           => '1000',
            'comment'              =>
                'Registered, Active and Total modems on CMTS',
                
                'vertical-label'       => 'Modems',
                
                'graph-legend-total'   => 'Total',
                'line-style-total'     => '##totalresource',
                'line-color-total'     => '##totalresource',
                'line-order-total'     => '1',
                
                'graph-legend-active'  => 'Active',
                'line-style-active'    => '##resourcepartusage',
                'line-color-active'    => '##resourcepartusage',
                'line-order-active'    => '2',
                
                'graph-legend-registered'  => 'Registered',
                'line-style-registered'    => '##resourceusage',
                'line-color-registered'    => '##resourceusage',
                'line-order-registered'    => '3',
                'descriptive-nickname'     => '%system-id%: All modems'
            };
        
        my $first = 1;
        foreach my $ifIndex ( @{$data->{'docsCableMaclayer'}} )
        {
            my $interface = $data->{'interfaces'}{$ifIndex};
            
            my $intf = $interface->{$data->{'nameref'}{'ifSubtreeName'}};
            
            if( $first )
            {
                $param->{'ds-expr-total'} =
                    '{' . $intf . '/Modems_Total}';
                $param->{'ds-expr-active'} =
                    '{' . $intf . '/Modems_Active}';
                $param->{'ds-expr-registered'} =
                    '{' . $intf . '/Modems_Registered}';
                $first = 0;
            }
            else
            {
                $param->{'ds-expr-total'} .=
                    ',{' . $intf . '/Modems_Total},+';
                $param->{'ds-expr-active'} .=
                    ',{' . $intf . '/Modems_Active},+';
                $param->{'ds-expr-registered'} .=
                    ',{' . $intf . '/Modems_Registered},+';
            }
        }

        my $macNode =
            $cb->getChildSubtree( $devNode,
                                  $data->{'docsConfig'}{
                                      'docsCableMaclayer'}{
                                          'subtreeName'} );
        if( defined( $macNode ) )
        {
            $cb->addLeaf( $macNode, 'All_Modems', $param, [] );
        }
        else
        {
            Error('Could not find the MAC layer subtree');
            exit 1;
        }
        
        # Apply selector actions
        foreach my $ifIndex ( @{$data->{'docsCableMaclayer'}} )
        {
            my $interface = $data->{'interfaces'}{$ifIndex};
            
            my $intf = $interface->{$data->{'nameref'}{'ifSubtreeName'}};
            
            my $monitor =
                $interface->{'selectorActions'}{'DocsisMacModemsMonitor'};
            if( defined( $monitor ) )
            {
                my $intfNode = $cb->getChildSubtree( $macNode, $intf );
                $cb->addLeaf( $intfNode, 'Modems_Registered',
                              {'monitor' => $monitor } );
            }
        }
    }

    if( scalar( @{$data->{'docsCableUpstream'}} ) > 0 )
    {
        my $upstrNode =
            $cb->getChildSubtree( $devNode,
                                  $data->{'docsConfig'}{'docsCableUpstream'}{
                                      'subtreeName'} );
        
        foreach my $ifIndex ( @{$data->{'docsCableUpstream'}} )
        {
            my $interface = $data->{'interfaces'}{$ifIndex};
            
            my $intf = $interface->{$data->{'nameref'}{'ifSubtreeName'}};
            
            my $monitor =
                $interface->{'selectorActions'}{'DocsisUpUtilMonitor'};
            if( defined( $monitor ) )
            {
                my $intfNode = $cb->getChildSubtree( $upstrNode, $intf );
                $cb->addLeaf( $intfNode, 'Util',
                              {'monitor' => $monitor } );
            }

            $monitor =
                $interface->{'selectorActions'}{'DocsisUpSlotsMonitor'};
            if( defined( $monitor ) )
            {
                my $intfNode = $cb->getChildSubtree( $upstrNode, $intf );
                $cb->addLeaf( $intfNode, 'ContSlots',
                              {'monitor' => $monitor } );
            }
        }

        # Override the overview shortcus defined in rfc2670.docsis-if.xml
        
        my $shortcuts = 'snr,fec,freq,modems,util';
        if( $devdetails->hasCap('cdxIfUpChannelMaxUGSLastFiveMins') )
        {
            $shortcuts .= ',ugs';
        }
        
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
                
                'overview-subleave-name-util' => 'Util_Summary',
                'overview-direct-link-util' => 'yes',
                'overview-direct-link-view-util' => 'expanded-dir-html',
                'overview-shortcut-text-util' => 'All utilization',
                'overview-shortcut-title-util' => 'All upstream utilization',
                'overview-page-title-util' => 'Upstream utilization',
                
                'overview-subleave-name-ugs' => 'Active_UGS',
                'overview-direct-link-ugs' => 'yes',
                'overview-direct-link-view-ugs' => 'expanded-dir-html',
                'overview-shortcut-text-ugs' => 'All UGS',
                'overview-shortcut-title-ugs' => 'Show all UGS in one page',
                'overview-page-title-ugs' => 'UGS Statistics'
            };

        $cb->addParams( $upstrNode, $param );
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
