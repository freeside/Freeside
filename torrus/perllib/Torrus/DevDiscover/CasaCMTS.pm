#  Copyright (C) 2010  Stanislav Sinyagin
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

# $Id: CasaCMTS.pm,v 1.1 2010-12-27 00:03:47 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# DOCSIS interface, CASA specific

package Torrus::DevDiscover::CasaCMTS;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'CasaCMTS'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


$Torrus::DevDiscover::RFC2863_IF_MIB::knownSelectorActions{
    'DocsisMacModemsMonitor'} = 'CasaCMTS';


our %oiddef =
    (
     'casaProducts' => '1.3.6.1.4.1.20858.2',
     );


sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;
    
    if( not $dd->oidBaseMatch
        ( 'casaProducts',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) or
        not $devdetails->isDevType('RFC2670_DOCS_IF') )
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
    
    push( @{$data->{'docsConfig'}{'docsCableMaclayer'}{'templates'}},
          'CasaCMTS::casa-docsis-mac-subtree' );
    
    foreach my $ifIndex ( @{$data->{'docsCableMaclayer'}} )
    {
        my $interface = $data->{'interfaces'}{$ifIndex};

        push( @{$interface->{'docsTemplates'}},
              'CasaCMTS::casa-docsis-mac-util' );
    }

    foreach my $ifIndex ( @{$data->{'docsCableUpstream'}} )
    {
        my $interface = $data->{'interfaces'}{$ifIndex};

        push( @{$interface->{'docsTemplates'}},
              'CasaCMTS::casa-docsis-upstream-util' );
    }
    
    foreach my $ifIndex ( @{$data->{'docsCableDownstream'}} )
    {
        my $interface = $data->{'interfaces'}{$ifIndex};
        
        push( @{$interface->{'docsTemplates'}},
              'CasaCMTS::casa-docsis-downstream-util' );
    }
    
    
    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my $data = $devdetails->data();


    if( scalar( @{$data->{'docsCableMaclayer'}} ) > 0 )
    {
        # Build All_Modems summary graph
        my $param = {
            'ds-type'              => 'rrd-multigraph',
            'ds-names'             => 'total,active,registered',        
            'graph-lower-limit'    => '0',
            'precedence'           => '1000',                          
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

        # for the sake of better Emacs formatting
        $param->{'comment'} =
            'Registered, Active and Total modems on CMTS';
        
        $param->{'nodeid'} =
            $data->{'docsConfig'}{'docsCableMaclayer'}{'nodeidCategory'} .
            '//%nodeid-device%//modems';
        
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
        
        # Override the overview shortcus defined in rfc2670.docsis-if.xml
        
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
    }
    
    if( scalar( @{$data->{'docsCableDownstream'}} ) > 0 )
    {
        my $downstrNode =
            $cb->getChildSubtree( $devNode,
                                  $data->{'docsConfig'}{'docsCableDownstream'}{
                                      'subtreeName'} );
        
        # Override the overview shortcus defined in rfc2670.docsis-if.xml
        
        my $shortcuts = 'util,modems';
        
        my $param = {        
            'overview-shortcuts' => $shortcuts,
            'overview-subleave-name-modems' => 'Modems',
            'overview-direct-link-modems' => 'yes',
            'overview-direct-link-view-modems' => 'expanded-dir-html',
            'overview-shortcut-text-modems' => 'All modems',
            'overview-shortcut-title-modems' =>
                'Show modem quantities in one page',
            'overview-page-title-modems' => 'Modem quantities',
            };
        
        $cb->addParams( $downstrNode, $param );
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
