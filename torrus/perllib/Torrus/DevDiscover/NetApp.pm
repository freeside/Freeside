#  Copyright (C) 2004  Shawn Ferry
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

# $Id: NetApp.pm,v 1.1 2010-12-27 00:03:55 ivan Exp $
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>

# NetApp.com storage products

package Torrus::DevDiscover::NetApp;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'NetApp'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

our %oiddef =
    (
     'netapp'                               => '1.3.6.1.4.1.789',
     'netapp1'                              => '1.3.6.1.4.1.789.1',
     'netappProducts'                       => '1.3.6.1.4.1.789.2',

     # netapp product 
     'netapp_product'                       => '1.3.6.1.4.1.789.1.1',
     'netapp_productVersion'                => '1.3.6.1.4.1.789.1.1.2.0',
     'netapp_productId'                     => '1.3.6.1.4.1.789.1.1.3.0',
     'netapp_productModel'                  => '1.3.6.1.4.1.789.1.1.5.0',
     'netapp_productFirmwareVersion'        => '1.3.6.1.4.1.789.1.1.6.0',
     
     # netapp sysstat
     'netapp_sysStat'                       => '1.3.6.1.4.1.789.1.2',
     'netapp_sysStat_cpuCount'              => '1.3.6.1.4.1.789.1.2.1.6.0',
     
     # netapp nfs
     'netapp_nfs'                           => '1.3.6.1.4.1.789.1.3',
     'netapp_nfsIsLicensed'                 => '1.3.6.1.4.1.789.1.3.3.1.0',
     
     # At a glance Lookup values seem to be the most common as opposed to
     # collecting NFS stats for v2 and v3 (and eventually v4 ) if No lookups
     # have been performed at discovery time we assume that vX is not in use.
     'netapp_tv2cLookups'              => '1.3.6.1.4.1.789.1.3.2.2.3.1.5.0',
     'netapp_tv3cLookups'              => '1.3.6.1.4.1.789.1.3.2.2.4.1.4.0',
     
     # netapp CIFS
     'netapp_cifs'                     => '1.3.6.1.4.1.789.1.7',
     'netapp_cifsIsLicensed'           => '1.3.6.1.4.1.789.1.7.21.0',
     
     # 4 - 19 should also be interesting
     # particularly cluster netcache stats
     );

#       netappFiler     OBJECT IDENTIFIER ::= { netappProducts 1 }
#       netappNetCache  OBJECT IDENTIFIER ::= { netappProducts 2 }
#       netappClusteredFiler    OBJECT IDENTIFIER ::= { netappProducts 3 }

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    return $dd->checkSnmpTable( 'netapp' );
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    my $result = $dd->retrieveSnmpOIDs
        ( 'netapp_productModel',  'netapp_productId',
          'netapp_productVersion', 'netapp_productFirmwareVersion',
          'netapp_nfsIsLicensed', 'netapp_cifsIsLicensed',
          'netapp_tv2cLookups', 'netapp_tv3cLookups' );
    
    $data->{'param'}->{'comment'} =
        sprintf('%s %s: %s %s',
                $result->{'netapp_productModel'},
                $result->{'netapp_productId'},
                $result->{'netapp_productVersion'},
                $result->{'netapp_productFirmwareVersion'});
    
    # At a glance Lookup values seem to be the most common as opposed to
    # collecting NFS stats for v2 and v3 (and eventually v4 ) if No lookups
    # have been performed at discovery time we assume that nfsvX is not in use.
    
    if( $result->{'netapp_nfsIsLicensed'} == 2 )
    {
        if( $result->{'netapp_tv2cLookups'} > 0 )
        {
            $devdetails->setCap('NetApp::nfsv2');
        }

        if( $result->{'netapp_tv3cLookups'} > 0 )
        {
            $devdetails->setCap('NetApp::nfsv3');
        }
    }

    if( $result->{'netapp_cifsIsLicensed'} == 2 )
    {
        $devdetails->setCap('NetApp::cifs');
    }
    
    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    my $data = $devdetails->data();

    $cb->addParams( $devNode, $data->{'params'} );

    # Add CPU Template
    $cb->addTemplateApplication( $devNode, 'NetApp::CPU');
    
    # Add Misc Stats
    $cb->addTemplateApplication( $devNode, 'NetApp::misc');

    if( $devdetails->hasCap('NetApp::nfsv2') )
    {
        $cb->addTemplateApplication( $devNode, 'NetApp::nfsv2');
    }

    if( $devdetails->hasCap('NetApp::nfsv3') )
    {
        $cb->addTemplateApplication( $devNode, 'NetApp::nfsv3');
    }

    if( $devdetails->hasCap('NetApp::cifs') )
    {
        Debug("Would add cifs here\n");
        #$cb->addTemplateApplication( $devNode, 'NetApp::cifs');
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
