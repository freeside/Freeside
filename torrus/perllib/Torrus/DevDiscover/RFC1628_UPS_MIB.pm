#  Copyright (C) 2008  Jon Nistor
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

# $Id: RFC1628_UPS_MIB.pm,v 1.1 2010-12-27 00:03:56 ivan Exp $
# Jon Nistor <nistor at snickers dot org>

# Discovery module for UPS-MIB (RFC 1628)
#
# Tested with:
#     ConnectUPS Web/SNMP Card V4.20 [powerware 9390]
#
# Issues with:
#     ConnectUPS Web/SNMP Card V3.16 [powerware 9155]
#      - InputFrequency and InputTruePower are missing from RFC UPS-MIB
#

package Torrus::DevDiscover::RFC1628_UPS_MIB;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'RFC1628_UPS_MIB'} = {
    'sequence'     => 100,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # UPS-MIB
     'upsIdent'                     => '1.3.6.1.2.1.33.1.1',
     'upsIdentManufacturer'         => '1.3.6.1.2.1.33.1.1.1.0',
     'upsIdentModel'                => '1.3.6.1.2.1.33.1.1.2.0',
     'upsIdentUPSSoftwareVersion'   => '1.3.6.1.2.1.33.1.1.3.0',
     'upsIdentAgentSoftwareVersion' => '1.3.6.1.2.1.33.1.1.4.0',
     'upsIdentName'                 => '1.3.6.1.2.1.33.1.1.5.0',

     'upsInputNumLines'             => '1.3.6.1.2.1.33.1.3.2.0',
     'upsOutputNumLines'            => '1.3.6.1.2.1.33.1.4.3.0',
     'upsBypassNumLines'            => '1.3.6.1.2.1.33.1.5.2.0'
     );



sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    return $dd->checkSnmpTable( 'upsIdent' );
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();
    my $session = $dd->session();

    my $upsInfo = $dd->retrieveSnmpOIDs('upsIdentManufacturer',
                  'upsIdentModel', 'upsIdentUPSSoftwareVersion',
                  'upsIdentAgentSoftwareVersion', 'upsIdentName',
                  'upsInputNumLines', 'upsOutputNumLines', 'upsBypassNumLines');

    $data->{'param'}{'comment'} = $upsInfo->{'upsIdentManufacturer'} . " " .
                            $upsInfo->{'upsIdentModel'} . " " . 
                            $upsInfo->{'upsIdentUPSSoftwareVersion'};

    # PROG: Discover number of lines (in,out,bypass)...
    $data->{'numInput'}  = $upsInfo->{'upsInputNumLines'};
    $data->{'numOutput'} = $upsInfo->{'upsOutputNumLines'};
    $data->{'numBypass'} = $upsInfo->{'upsBypassNumLines'};

    Debug("UPS Lines  Input: " . $data->{'numInput'} .
                  ", Output: " . $data->{'numOutput'} .
                  ", Bypass: " . $data->{'numBypass'} );

    if( $devdetails->param('RFC1628_UPS::disable-input') ne 'yes' )
    {
        $devdetails->setCap('UPS-input');
    }

    if( $devdetails->param('RFC1628_UPS::disable-output') ne 'yes' )
    {
        $devdetails->setCap('UPS-output');
    }

    if( $devdetails->param('RFC1628_UPS::disable-bypass') ne 'yes' )
    {
        $devdetails->setCap('UPS-bypass');
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    my $data = $devdetails->data();

    # PROG: Add static battery information
    $cb->addSubtree( $devNode, 'Battery',
                   { 'precedence' => 999 },
                   [ 'RFC1628_UPS_MIB::battery-subtree' ] );
    
    if( $devdetails->hasCap('UPS-input') )
    {
        my $nodeInput = $cb->addSubtree( $devNode, 'Input',
                                  { 'comment' => 'Input feeds' },
                                  [ 'RFC1628_UPS_MIB::ups-input-subtree' ] );

        foreach my $INDEX ( 1 .. $data->{'numInput'} )
        {
            $cb->addSubtree( $nodeInput, sprintf('Phase_%d', $INDEX),
                             { 'ups-input-idx' => $INDEX },
                             [ 'RFC1628_UPS::ups-input-leaf' ] );
        }
    }

    if( $devdetails->hasCap('UPS-output') )
    {
        my $nodeOutput = $cb->addSubtree( $devNode, 'Output',
                                   { 'comment' => 'Output feeds' },
                                   [ 'RFC1628_UPS_MIB::ups-output-subtree' ] );

        foreach my $INDEX ( 1 .. $data->{'numOutput'} )
        {
            $cb->addSubtree( $nodeOutput, sprintf('Phase_%d', $INDEX),
                             { 'ups-output-idx' => $INDEX },
                             [ 'RFC1628_UPS::ups-output-leaf' ] );
        }
    }

    if( $devdetails->hasCap('UPS-bypass') )
    {
        my $nodeBypass = $cb->addSubtree( $devNode, 'Bypass',
                                   { 'comment' => 'Bypass feeds' },
                                   [ 'RFC1628_UPS_MIB::ups-bypass-subtree' ] );

        foreach my $INDEX ( 1 .. $data->{'numBypass'} )
        {
            $cb->addSubtree( $nodeBypass, sprintf('Phase_%d', $INDEX),
                             { 'ups-bypass-idx' => $INDEX },
                             [ 'RFC1628_UPS::ups-bypass-leaf' ] );
        }
    }

}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
