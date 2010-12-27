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

# $Id: F5BigIp.pm,v 1.1 2010-12-27 00:03:48 ivan Exp $
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>

# F5 BigIp Load Balancer

package Torrus::DevDiscover::F5BigIp;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'F5BigIp'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

our %oiddef =
    (
     # F5
     'f5'                           => '1.3.6.1.4.1.3375',

     '4.x_globalStatUptime'         => '1.3.6.1.4.1.3375.1.1.1.2.1.0',
     '3.x_uptime'                   => '1.3.6.1.4.1.3375.1.1.50.0',

     '4.x_globalAttrProductCode'    => '1.3.6.1.4.1.3375.1.1.1.1.5.0',

     '4.x_virtualServer'            => '1.3.6.1.4.1.3375.1.1.3',
     '4.x_virtualServerNumber'      => '1.3.6.1.4.1.3375.1.1.3.1.0',
     '4.x_virtualServerTable'       => '1.3.6.1.4.1.3375.1.1.3.2',
     '4.x_virtualServerIp'          => '1.3.6.1.4.1.3375.1.1.3.2.1.1',
     '4.x_virtualServerPort'        => '1.3.6.1.4.1.3375.1.1.3.2.1.2',
     '4.x_virtualServerPool'        => '1.3.6.1.4.1.3375.1.1.3.2.1.30',

     '4.x_poolTable'                => '1.3.6.1.4.1.3375.1.1.7.2',
     '4.x_poolName'                 => '1.3.6.1.4.1.3375.1.1.7.2.1.1',

     '4.x_poolMemberTable'          => '1.3.6.1.4.1.3375.1.1.8.2',
     '4.x_poolMemberPoolName'       => '1.3.6.1.4.1.3375.1.1.8.2.1.1',
     '4.x_poolMemberIpAddress'      => '1.3.6.1.4.1.3375.1.1.8.2.1.2',
     '4.x_poolMemberPort'           => '1.3.6.1.4.1.3375.1.1.8.2.1.3',

     '4.x_sslProxyTable'            => '1.3.6.1.4.1.3375.1.1.9.2.1',
     '4.x_sslProxyOrigIpAddress'    => '1.3.6.1.4.1.3375.1.1.9.2.1.1',
     '4.x_sslProxyOrigPort'         => '1.3.6.1.4.1.3375.1.1.9.2.1.2',
     '4.x_sslProxyDestIpAddress'    => '1.3.6.1.4.1.3375.1.1.9.2.1.3',
     '4.x_sslProxyDestPort'         => '1.3.6.1.4.1.3375.1.1.9.2.1.4',
     '4.x_sslProxyConnLimit'        => '1.3.6.1.4.1.3375.1.1.9.2.1.23',

     );

# from https://secure.f5.com/validate/help.jsp
#HA (BIG-IP high availability software)
#3DNS (3-DNS software)
#LC (BIG-IP Link Controller software)
#LB (BIG-IP Load Balancer 520)
#FLB (BIG-IP FireGuard 520)
#CLB (BIG-IP Cache Load Balancer 520)
#SSL (BIG-IP eCommerce Load Balancer 520)
#XLB (BIG-IP user-defined special purpose product for 520 platforms)
#ISMAN (iControl Services Manager)

our %f5_product = (
    '1'     => { 'product' => 'indeterminate',  'supported' => 0, },
    '2'     => { 'product' => 'ha',             'supported' => 1, },
    '3'     => { 'product' => 'lb',             'supported' => 1, },
    '4'     => { 'product' => 'threedns',       'supported' => 0, },
    '5'     => { 'product' => 'flb',            'supported' => 0, },
    '6'     => { 'product' => 'clb',            'supported' => 0, },
    '7'     => { 'product' => 'xlb',            'supported' => 0, },
    '8'     => { 'product' => 'ssl',            'supported' => 1, },
    '10'    => { 'product' => 'test',           'supported' => 0, },
    '99'    => { 'product' => 'unsupported',    'supported' => 0, },
    );

our %f5_sslGatewayLevel = (
    '1'     => 'none',
    '3'     => 'tps200',
    '4'     => 'tps400',
    '5'     => 'tps600',
    '6'     => 'tps800',
    '7'     => 'tps1000',
    '9'     => 'tps500',
    '10'    => 'tps1500',
    '11'    => 'tps2000',
    '99'    => 'unsupported',
    );




sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;
    my $data = $devdetails->data();

    # You would think globalAttrProductCode would work well
    # I need more examples to see if ha(2) is specific to
    # BipIP HA or any ha f5 product

    if( not $dd->checkSnmpTable( 'f5' ) )
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

    # SNMP on F5 boxes will become unresponsive over time with large
    # enough oids-per-pdu values.  10 appears to work for everything however
    # no exhaustive testing has been done to determine if a higer number
    # could be used.
    if( not defined( $data->{'param'}{'snmp-oids-per-pdu'} ) )
    {
        my $oidsPerPDU = $devdetails->param('F5BigIp::snmp-oids-per-pdu');
        if( $oidsPerPDU == 0 )
        {
            $oidsPerPDU = 10;
        }
        $data->{'param'}{'snmp-oids-per-pdu'} = $oidsPerPDU;
    }

    # this is rather basic, per-capability checking
    # may be required in the future

    if( $dd->checkSnmpOID('4.x_globalStatUptime') )
    {
        $devdetails->setCap('BigIp_4.x');
    }
    elsif( $dd->checkSnmpOID('3.x_uptime') )
    {
        # for v3.x we are not supporting detailed stats, so don't check
        # anything else
        $devdetails->setCap('BigIp_3.x');
        return 1;
    }

    my $product_name;
    my $product_name;
    my $result = $dd->retrieveSnmpOIDs( '4.x_globalAttrProductCode' );
    my $product_code = $result->{'4.x_globalAttrProductCode'};

    $product_name = %f5_product->{$product_code}->{'product'};
    if( %f5_product->{$product_code}->{'supported'} )
    {
        $devdetails->setCap( 'BigIp_' . $product_name );
    }
    else
    {
        if( defined($product_name) )
        {
            Debug("Found an unsupported F5 product '$product_name'");
        }
        else
        {
            Debug("Found an unknown F5 product");
        }
        return 0;
    }

    my $poolTable = $session->get_table( -baseoid =>
                                 $dd->oiddef('4.x_poolTable') );

    if( defined( $poolTable ) )
    {
        $devdetails->storeSnmpVars( $poolTable );
        $devdetails->setCap('BigIp_4.x_PoolTable');

        my $ref = {};
        $ref->{'indices'} = [];
        $data->{'poolTable'} = $ref;

        foreach my $INDEX ( $devdetails->
                            getSnmpIndices( $dd->oiddef('4.x_poolName') ) )
        {
            push( @{$ref->{'indices'}}, $INDEX );
            my $pool = $devdetails->snmpVar($dd->oiddef('4.x_poolName') .
                                            '.' . $INDEX );

            my $nick = $pool;
            $nick =~ s/\W/_/g;
            $nick =~ s/_+/_/g;

            my $param = {};
            $ref->{$INDEX}->{'param'} = $param;
            $param->{'nick'} = $nick;
            $param->{'pool'} = $pool;
            $param->{'descr'} = "Stats for Pool $pool";
            $param->{'INDEX'} = $INDEX;
        }

    }

    my $poolMemberTable =
        $session->get_table( -baseoid =>
                             $dd->oiddef('4.x_poolMemberTable') );

    if( defined( $poolMemberTable ) )
    {
        $devdetails->storeSnmpVars( $poolMemberTable );
        $devdetails->setCap('BigIp_4.x_PoolMemberTable');

        my $ref = {};
        $data->{'poolMemberTable'} = $ref;

        foreach my $INDEX
            ( $devdetails->
              getSnmpIndices( $dd->oiddef('4.x_poolMemberPoolName') ) )
        {
            push( @{ $ref->{'indices'} }, $INDEX );
            my $pool =
                $devdetails->snmpVar($dd->oiddef('4.x_poolMemberPoolName') .
                                     '.' . $INDEX );
            my $ip =
                $devdetails->snmpVar($dd->oiddef('4.x_poolMemberIpAddress') .
                                     '.' . $INDEX );
            my $port =
                $devdetails->snmpVar($dd->oiddef('4.x_poolMemberPort') .
                                     '.' . $INDEX );

            my $nick = "MEMBER_${pool}_${ip}_${port}";
            $nick =~ s/\W/_/g;
            $nick =~ s/_+/_/g;

            my $param = {};
            $ref->{$INDEX}->{'param'} = $param;
            $param->{'nick'} = $nick;
            $param->{'pool'} = $pool;
            $param->{'descr'} = "Member of Pool $pool IP: $ip Port: $port";
            $param->{'INDEX'} = $INDEX;
        }

    }

    my $virtServerNumber = $dd->retrieveSnmpOIDs( '4.x_virtualServerNumber' );
    if( $virtServerNumber->{'4.x_virtualServerNumber'} > 0 )
    {
        my $virtServer = $session->get_table( -baseoid =>
                                          $dd->oiddef('4.x_virtualServer') );
        if( defined( $virtServer ) )
        {
            $devdetails->storeSnmpVars( $virtServer );
            $devdetails->setCap('BigIp_4.x_VirtualServer');

            my $ref = {};
            $data->{'virtualServer'} = $ref;

            foreach my $INDEX
                ( $devdetails->
                  getSnmpIndices( $dd->oiddef('4.x_virtualServerIp') ) )
            {
                push( @{ $ref->{'indices'} }, $INDEX);
                my $pool = $devdetails->snmpVar(
                                $dd->oiddef('4.x_virtualServerPool') .
                                '.' . $INDEX );
                my $ip = $devdetails->snmpVar(
                                $dd->oiddef('4.x_virtualServerIp') .
                                '.' . $INDEX );
                my $port = $devdetails->snmpVar(
                                $dd->oiddef('4.x_virtualServerPort') .
                                '.' . $INDEX );

                my $param = {};
                $ref->{$INDEX}->{'param'} = $param;

                my $descr = "Virtual Server Pool: $pool IP: $ip Port: $port";
                my $nick = "VIP_${pool}_${ip}_${port}";
                $nick =~ s/\W/_/g;
                $nick =~ s/_+/_/g;

                $param->{'INDEX'} = $INDEX;
                $param->{'descr'} = $descr;
                $param->{'nick'} = $nick;
                $param->{'pool'} = $pool;
            }
        }
        else
        {
            Debug("Virtual Servers Defined but not able to be configured");
        }
    }

    my $sslProxyTable = $session->get_table( -baseoid =>
                            $dd->oiddef('4.x_sslProxyTable') );

    if( defined( $sslProxyTable ) )
    {
        $devdetails->storeSnmpVars( $sslProxyTable );
        $devdetails->setCap('BigIp_4.x_sslProxyTable');

        my $ref = {};
        $ref->{'indices'} = [];
        $data->{'sslProxyTable'} = $ref;

        foreach my $INDEX ( $devdetails->
            getSnmpIndices( $dd->oiddef('4.x_sslProxyOrigIpAddress') ) )
        {
            push( @{$ref->{'indices'}}, $INDEX );

            my $origIp = $devdetails->snmpVar(
                    $dd->oiddef('4.x_sslProxyOrigIpAddress')
                    . '.' .  $INDEX );

            my $origPort = $devdetails->snmpVar(
                    $dd->oiddef('4.x_sslProxyOrigPort')
                    . '.' .  $INDEX );

            my $destIp = $devdetails->snmpVar(
                    $dd->oiddef('4.x_sslProxyDestIpAddress')
                    . '.' .  $INDEX );

            my $destPort = $devdetails->snmpVar(
                    $dd->oiddef('4.x_sslProxyDestPort')
                    . '.' .  $INDEX );

            my $connLimit = $devdetails->snmpVar(
                    $dd->oiddef('4.x_sslProxyConnLimit')
                    . '.' .  $INDEX );



            my $nick = $origIp . '_' . $origPort . '_' . $destIp .
                    '_' . $destPort;

            my $param = {};
            $ref->{$INDEX}->{'param'} = $param;
            $param->{'nick'} = $nick;
            $param->{'descr'} = "Stats for SSL Proxy Address: " .
                    "${origIp}:${origPort} -> ${destIp}:${destPort}";
            $param->{'INDEX'} = $INDEX;
            $param->{'connLimit'} = $connLimit;

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


    my $bigIpName = 'BigIp_Global_Stats';

    my $bigIpParam = {
        'precedence'         => '-100',
        'comment'            => 'BigIp Global Stats',
        'rrd-create-dstype'  => 'GAUGE', };

    if( $devdetails->hasCap('BigIp_4.x') )
    {
        my $bigIpStatsNode = $cb->addSubtree( $devNode, $bigIpName,
                $bigIpParam, [ 'F5BigIp::BigIp_4.x' ]);

        if( $devdetails->hasCap('BigIp_ssl') )
        {
            $cb->addTemplateApplication
                ( $bigIpStatsNode , 'F5BigIp::BigIp_4.x_sslProxy_Global' );
        }
    }
    elsif( $devdetails->hasCap('BigIp_3.x') )
    {
        $cb->addSubtree( $devNode, $bigIpName, $bigIpParam,
                         [ 'F5BigIp::BigIp_3.x' ]);
    }

    my $virtName = 'BigIp_VirtualServers';

    my $virtParam = {
        'precedence'        => '-200',
        'comment'           => 'Virtual Server(VIP) Stats',
    };

    my $virtTree;

    if( $devdetails->hasCap('BigIp_4.x_VirtualServer') )
    {
        my @templates =
            ( 'F5BigIp::BigIp_4.x_virtualServer-actvconn-overview' );
        #    'F5BigIp::BigIp_4.x_virtualServer-connrate-overview');

        $virtTree =
            $cb->addSubtree( $devNode, $virtName, $virtParam, \@templates );

        my $ref = $data->{'virtualServer'};

        foreach my $INDEX ( @{ $ref->{'indices'} } )
        {
            my $server = $ref->{$INDEX}->{'param'};

            $server->{'precedence'} = '-100';

            $cb->addSubtree( $virtTree, $server->{'nick'}, $server,
                          [ 'F5BigIp::BigIp_4.x_virtualServer' ] );
        }
    }

    my $poolName = 'BigIp_Pools';
    my $poolParam = {
        'precedence'        => '-300',
        'comment'           => 'Pool Stats',
    };

    my $poolTree;

    if( $devdetails->hasCap('BigIp_4.x_PoolTable') )
    {
        $poolTree =
            $cb->addSubtree( $devNode, $poolName, $poolParam,
                             ['F5BigIp::BigIp_4.x_pool-actvconn-overview']);
        my $ref = $data->{'poolTable'};

        foreach my $INDEX ( @{ $ref->{'indices'} } )
        {
            my $pool = $ref->{$INDEX}->{'param'};

            $pool->{'precedence'} = '-100';

            $cb->addSubtree( $poolTree, $pool->{'pool'}, $pool,
                          [ 'F5BigIp::BigIp_4.x_pool' ] );
        }

    }

    my $poolMemberName = 'BigIp_Pool_Members';

    my $poolMemberParam = {
        'precedence'        => '-400',
        'comment'           => 'Pool Member Stats',
    };

    my $poolMemberTree;

    if( $devdetails->hasCap('BigIp_4.x_PoolMemberTable') )
    {
        $poolMemberTree =
            $cb->addSubtree( $devNode, $poolMemberName, $poolMemberParam );
        my $ref = $data->{'poolMemberTable'};

        foreach my $INDEX ( @{ $ref->{'indices'} } )
        {
            my $poolMemberPoolTree;
            my $lastPoolTree;
            my $server = $ref->{$INDEX}->{'param'};

            my $poolMemberPoolName = $server->{'pool'};
            my $poolMemberPoolParam = {
                'precidence'    => '-100',
                'comment'       => "Members of the $server->{'pool'} Pool",
            };


            if( not defined( $lastPoolTree ) or
                $poolMemberPoolName !~ /\b$lastPoolTree\b/ )
            {
                my @templates =
                    ( 'F5BigIp::BigIp_4.x_poolMember-actvconn-overview' );
                $poolMemberPoolTree =
                    $cb->addSubtree( $poolMemberTree, $poolMemberPoolName,
                                     $poolMemberPoolParam, \@templates );

                $lastPoolTree = $poolMemberPoolName;

                $server->{'precedence'} = '-100';

                $cb->addSubtree( $poolMemberPoolTree, $server->{'nick'}, $server,
                              [ 'F5BigIp::BigIp_4.x_poolMember' ] );
            }
        }
    }


    # BigIP SSL Product Support
    if( $devdetails->hasCap('BigIp_4.x_sslProxyTable') )
    {

        my $bigIpSSLProxies = 'BigIp_SSL_Proxies';

        my $bigIpSSLParam = {
            'comment'            => 'BigIp SSL Proxies',
            'rrd-create-dstype'  => 'COUNTER', };

        my $sslProxyTree = $cb->addSubtree(
                    $devNode, $bigIpSSLProxies, $bigIpSSLParam,
                    [ 'F5BigIp::BigIp_4.x_sslProxy-currconn-overview' ]);

        my $ref = $data->{'sslProxyTable'};

        foreach my $INDEX ( @{ $ref->{'indices'} } )
        {
            my $proxy = $ref->{$INDEX}->{'param'};

            $cb->addSubtree( $sslProxyTree, $proxy->{'nick'}, $proxy,
                    [ 'F5BigIp::BigIp_4.x_sslProxy' ] );
        }

    }

}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
