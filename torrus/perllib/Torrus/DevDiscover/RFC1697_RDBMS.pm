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

# $Id: RFC1697_RDBMS.pm,v 1.1 2010-12-27 00:03:52 ivan Exp $
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>

# RDBMS MIB

package Torrus::DevDiscover::RFC1697_RDBMS;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'RFC1697_RDBMS'} = {
    'sequence'     => 100,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

our %oiddef =
    (
     # RDBMS-MIB
     'rdbms'                            => '1.3.6.1.2.1.39',

     'rdbmsDbTable'                     => '1.3.6.1.2.1.39.1.1.1',
     'rdbmsDbIndex'                     => '1.3.6.1.2.1.39.1.1.1.1',
     'rdbmsDbVendorName'                => '1.3.6.1.2.1.39.1.1.1.3',
     'rdbmsDbName'                      => '1.3.6.1.2.1.39.1.1.1.4',
     'rdbmsDbContact'                   => '1.3.6.1.2.1.39.1.1.1.5',
     'rdbmsDbPrivateMIBOID'             => '1.3.6.1.2.1.39.1.1.1.2',

     'rdbmsDbInfoTable'                 => '1.3.6.1.2.1.39.1.2.1',
     'rdbmsDbInfoProductName'           => '1.3.6.1.2.1.39.1.2.1.1',
     'rdbmsDbInfoVersion'               => '1.3.6.1.2.1.39.1.2.1.2',
     'rdbmsDbInfoSizeUnits'             => '1.3.6.1.2.1.39.1.2.1.3',

     # currently ignored, generally identical to rdbmsDb for oracle
     'rdbmsSrvTable'                    => '1.3.6.1.2.1.39.1.5.1',
     'rdbmsSrvVendorName'               => '1.3.6.1.2.1.39.1.5.1.2',
     'rdbmsSrvProductName'              => '1.3.6.1.2.1.39.1.5.1.3',
     'rdbmsSrvContact'                  => '1.3.6.1.2.1.39.1.5.1.4',
     'rdbmsSrvPrivateMIBOID'            => '1.3.6.1.2.1.39.1.5.1.1',

     # Oracle MIB base
     'ora'                              => '1.3.6.1.4.1.111',

     );




sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    return $dd->checkSnmpTable('rdbms');
}

sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    my $DbInfoSizeUnits = {
        1 => '1',                       # bytes
        2 => '1024',                    # kbytes
        3 => '1048576',                 # mbytes
        4 => '1073741824',              # gbytes
        5 => '1099511627776',           # tbytes
    };

    my $dbTypes = {
        ora => $dd->oiddef('ora'),
    };


    my $rdbmsDbTable = $session->get_table( -baseoid =>
                                            $dd->oiddef('rdbmsDbTable') );

    my $rdbmsDbInfoTable =
        $session->get_table( -baseoid =>
                             $dd->oiddef('rdbmsDbInfoTable') );

    if( defined( $rdbmsDbTable ) )
    {
        $devdetails->storeSnmpVars($rdbmsDbTable);
        $devdetails->setCap('RDBMS::DbTable');

        if( defined( $rdbmsDbInfoTable ) )
        {
            $devdetails->storeSnmpVars($rdbmsDbInfoTable);
            $devdetails->setCap('RDBMS::DbInfoTable');
        }
        else
        {
            Debug("No Actively Opened Instances");
        }

        my $ref = {};
        $ref->{'indices'} = [];
        $data->{'DbTable'} = $ref;

        foreach my $INDEX
            ( $devdetails->getSnmpIndices( $dd->oiddef('rdbmsDbIndex') ) )
        {
            
            push( @{$ref->{'indices'}}, $INDEX );
            
            my $vendor =
                $devdetails->snmpVar( $dd->oiddef('rdbmsDbVendorName') .
                                      '.' . $INDEX );

            my $product =
                $devdetails->snmpVar( $dd->oiddef('rdbmsDbInfoProductName') .
                                      '.' . $INDEX );

            my $version =
                $devdetails->snmpVar( $dd->oiddef('rdbmsDbInfoVersion') .
                                      '.' . $INDEX );

            my $sizeUnits =
                $devdetails->snmpVar( $dd->oiddef('rdbmsDbInfoSizeUnits') .
                                      '.' . $INDEX );
            $sizeUnits = $DbInfoSizeUnits->{$sizeUnits};

            my $dbName =
                $devdetails->snmpVar( $dd->oiddef('rdbmsDbName') .
                                      '.' . $INDEX );

            my $dbContact =
                $devdetails->snmpVar( $dd->oiddef('rdbmsDbContact') .
                                      '.' . $INDEX );

            my $dbMIBOID =
                $devdetails->snmpVar( $dd->oiddef('rdbmsDbPrivateMIBOID')
                                      . '.' . $INDEX );

            my $nick = "Vendor_" . $vendor . "_DB_" . $dbName;
            $nick =~ s/^\///;
            $nick =~ s/\W/_/g;
            $nick =~ s/_+/_/g; 

            my $descr = "Vendor: $vendor DB: $dbName";
            $descr .= " Contact: $dbContact" if $dbContact;
            $descr .= " Version: $version" if $version;

            my $param = {};
            $ref->{$INDEX}->{'param'} = $param;
            $param->{'vendor'} = $vendor;
            $param->{'product'} = $product;
            $param->{'dbVersion'} = $version;
            $param->{'dbSizeUnits'} = $sizeUnits;
            $param->{'dbName'} = $dbName;
            $param->{'dbMIBOID'} = $dbMIBOID;
            $param->{'nick'} = $nick;
            $param->{'comment'} = $descr;
            $param->{'precedence'} = 1000 - $INDEX;

            foreach my $dbType ( keys %{ $dbTypes } )
            {
                if( Net::SNMP::oid_base_match
                    ( $dbTypes->{$dbType}, $dbMIBOID ) )
                {
                    if( not exists $data->{$dbType} )
                    {
                        $data->{$dbType} = {};
                    }
                    $data->{$dbType}->{$dbName}->{'index'} = $INDEX;
                    Debug(" Added $dbName -> $INDEX to $dbType ");
                    last;
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

    return unless $devdetails->isDevType("RDBMS");

    my $appParam = {
        'precedence'    =>  -100000,
    };

    my $appNode = $cb->addSubtree( $devNode, 'Applications', $appParam );

    my $param = { };
    my $oraNode = $cb->addSubtree( $appNode, 'Oracle', $param );

    if( $devdetails->hasCap('RDBMS::DbTable') )
    {
        my $ref = $data->{'DbTable'};

        foreach my $INDEX ( @{ $ref->{'indices'} } )
        {
            my $param = $ref->{$INDEX}->{'param'};
            $cb->addSubtree( $oraNode, $param->{'nick'}, $param,
                             [ 'RFC1697_RDBMS::rdbms-dbtable' ], );
        }

    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
