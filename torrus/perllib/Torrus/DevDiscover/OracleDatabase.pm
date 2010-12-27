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

# $Id: OracleDatabase.pm,v 1.1 2010-12-27 00:03:49 ivan Exp $
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>

# Oracle Database MIB

package Torrus::DevDiscover::OracleDatabase;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'OracleDatabase'} = {
    'sequence'     => 600,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

our %oiddef =
    (
     # Oracle Database
     'oraDb'                            => '1.3.6.1.4.1.111.4.1',

     'oraDbConfigDbBlockSize'           => '1.3.6.1.4.1.111.4.1.7.1.3',

     'oraDbSysTable'                    => '1.3.6.1.4.1.111.4.1.1.1',

     'oraDbTablespace'                  => '1.3.6.1.4.1.111.4.1.2.1',
     'oraDbTablespaceIndex'             => '1.3.6.1.4.1.111.4.1.2.1.1',
     'oraDbTablespaceName'              => '1.3.6.1.4.1.111.4.1.2.1.2',

     'oraDbDataFile'                    => '1.3.6.1.4.1.111.4.1.3.1',
     'oraDbDataFileIndex'               => '1.3.6.1.4.1.111.4.1.3.1.1',
     'oraDbDataFileName'                => '1.3.6.1.4.1.111.4.1.3.1.2',

     'oraDbLibraryCache'                => '1.3.6.1.4.1.111.4.1.4.1',
     'oraDbLibraryCacheIndex'           => '1.3.6.1.4.1.111.4.1.4.1.1',
     'oraDbLibraryCacheNameSpace'       => '1.3.6.1.4.1.111.4.1.4.1.2',

     'oraDbLibraryCacheSumTable'        => '1.3.6.1.4.1.111.4.1.5.1',

     'oraDbSGATable'                    => '1.3.6.1.4.1.111.4.1.6.1',

     );

my $DbInfoSizeUnits =
{
    1 => '1',                       # bytes
    2 => '1024',                    # kbytes
    3 => '1048576',                 # mbytes
    4 => '1073741824',              # gbytes
    5 => '1099511627776',           # tbytes
};

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    return $dd->checkSnmpTable('oraDb');
}

sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    if( not defined( $data->{'param'}{'snmp-oids-per-pdu'} ) )
    {
        $data->{'param'}{'snmp-oids-per-pdu'} = '10';
    }
    
    my $dbType = $data->{'ora'};

    # my $oraTableSpaceCols = (
    #     $dd->oiddef('oraDbTablespaceIndex'),
    #     $dd->oiddef('oraDbTablespaceName'),
    #     );

    # my $oraTableSpace = $session->get_entries( -columns => [
    #         $dd->oiddef('oraDbTablespaceIndex'),
    #         $dd->oiddef('oraDbTablespaceName'),
    #         ], );

    my $oraTableSpace = $session->get_table( -baseoid =>
                                             $dd->oiddef('oraDbTablespace'),
                                             );


    if( defined($oraTableSpace) )
    {
        $devdetails->setCap('oraTableSpace');
        $devdetails->storeSnmpVars($oraTableSpace);

    }

    ##

    # my @oraDbDataFileCols = (
    #     $dd->oiddef('oraDbDataFileIndex'),
    #     $dd->oiddef('oraDbDataFileName'),
    #     );

    # my $oraDbDataFile = $session->get_entries( -columns => [
    #     @oraDbDataFileCols ], );

    my $oraDbDataFile =
        $session->get_table( -baseoid => $dd->oiddef('oraDbDataFile') );

    if( defined($oraDbDataFile) )
    {
        $devdetails->setCap('oraDbDataFile');
        $devdetails->storeSnmpVars($oraDbDataFile);
    }

    ##

    # my @oraDbLibraryCacheCols = (
    #     $dd->oiddef('oraDbLibraryCacheIndex'),
    #     $dd->oiddef('oraDbLibraryCacheNameSpace'),
    #     );

    # my $oraDbLibraryCache = $session->get_entries( -columns => [
    #     @oraDbLibraryCacheCols ], );

    my $oraDbLibraryCache =
        $session->get_table( -baseoid => $dd->oiddef('oraDbLibraryCache') );

    if( defined($oraDbLibraryCache) )
    {
        $devdetails->setCap('oraDbLibraryCache');
        $devdetails->storeSnmpVars($oraDbLibraryCache);
    }

    Debug("Looking For dbNames");

    foreach my $dbName ( keys %{ $dbType } )
    {
        Debug("DBName: $dbName");

        my $dbIndex = $dbType->{$dbName}->{'index'};
        Debug("DBIndex: $dbIndex");

        my $db = {};
        $dbType->{$dbName} = $db;

        my $oid = $dd->oiddef('oraDbConfigDbBlockSize') . '.' .  $dbIndex;
        my $result = $session->get_request( -varbindlist => [ $oid ] );
        
        
        if( $session->error_status() == 0 and $result->{$oid} > 0 )
        {
            my $blocksize = $result->{$oid};
            $dbType->{$dbName}->{'dbBlockSize'} = $blocksize;
            Debug("DB Block Size: $blocksize");
        }
        Debug($session->error());

        if( $devdetails->hasCap('oraTableSpace') )
        {
            my $ref = {};
            $db->{'oraTableSpace'} = $ref;

            # Table Space
            foreach my $tsIndex
                ( $devdetails->
                  getSnmpIndices( $dd->oiddef('oraDbTablespaceIndex') .
                                  '.' . $dbIndex ) )
            {
                my $tsName =
                    $devdetails->snmpVar( $dd->oiddef('oraDbTablespaceName') .
                                          '.' . $dbIndex . '.' . $tsIndex );
                
                $ref->{$tsName} = $tsIndex;
            }
        }

        if( $devdetails->hasCap('oraDbDataFile') )
        {
            my $ref = {};
            $db->{'oraDbDataFile'} = $ref;

            # Data File
            foreach my $dfIndex
                ( $devdetails->
                  getSnmpIndices( $dd->oiddef('oraDbDataFileIndex') .
                                  '.' . $dbIndex ) )
            {
                my $dfName =
                    $devdetails->snmpVar( $dd->oiddef('oraDbDataFileName') .
                                          '.' . $dbIndex . '.' . $dfIndex );

                $ref->{$dfName} = $dfIndex;
            }
        }
        
        if( $devdetails->hasCap('oraDbLibraryCache') )
        {
            my $ref = {};
            $db->{'oraDbLibraryCache'} = $ref;

            # Library Cache
            foreach my $lcIndex
                ( $devdetails->
                  getSnmpIndices( $dd->oiddef('oraDbLibraryCacheIndex') .
                                  '.' . $dbIndex ) )
            {
                my $lcName =
                    $devdetails->
                    snmpVar( $dd->oiddef('oraDbLibraryCacheNameSpace') .
                             '.' . $dbIndex . '.' . $lcIndex );
                
                $ref->{$lcName} = $lcIndex;
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

    my $dbType = $data->{'ora'};

    my $appNode = $cb->addSubtree($devNode, 'Applications' );
    my $vendorNode = $cb->addSubtree($appNode, 'Oracle' );

    foreach my $dbName ( keys %{ $dbType } )
    {
        my $db = $dbType->{$dbName};
        my $dbIndex = $dbType->{$dbName}->{'index'};
        my $dbBlockSize = $dbType->{$dbName}->{'dbBlockSize'};

        my $dbNick = $dbName;
        $dbNick =~ s/^\///;
        $dbNick =~ s/\W/_/g;
        $dbNick =~ s/_+/_/g;

        my $dbParam = {
            'dbName' => $dbName,
            'precedence' => sprintf("%d", 10000 - $dbIndex),
            'vendor' => 'Oracle',
            'dbNick' => $dbNick,
        };

        my @dbTemplates = (
                           'OracleDatabase::Sys',
                           'OracleDatabase::CacheSum',
                           'OracleDatabase::SGA',
                           );

        my $dbNode = $cb->addSubtree($vendorNode, "Vendor_Oracle_DB_$dbNick",
                                     $dbParam, [ @dbTemplates ] );

        if( $devdetails->hasCap('oraTableSpace') )
        {
            my $tsParam = {
                'comment' => "Table space for $dbName",
                'precedence' => "600",
            };

            my $tsNode = $cb->addSubtree($dbNode, 'Table_Space', $tsParam );

            foreach my $tsName ( keys %{ $db->{'oraTableSpace'} } )
            {
                my $INDEX = $db->{'oraTableSpace'}->{$tsName};

                my $nick = $tsName;
                $nick =~ s/^\///;
                $nick =~ s/\W/_/g;
                $nick =~ s/_+/_/g;

                my $title = '%system-id%' . " $dbName $tsName";

                my $tsParam = {
                    'comment'   => "Table Space: $tsName",
                    'precedence' => sprintf("%d", 10000 - $INDEX),
                    'table-space-nick' => $nick,
                    'table-space-name' => $tsName,
                    'graph-title' => $title,
                    'descriptive-nickname' => $title,
                };

                $cb->addSubtree( $tsNode, $nick, $tsParam,
                                 [ 'OracleDatabase::table-space' ] );
                Debug("Will add TableSpace: $tsName");
            }
        }

        if( $devdetails->hasCap('oraDbDataFile') )
        {
            my $dfParam = {
                'comment' => "Data Files for $dbName",
                'precedence' => "500",
            };

            my $dfNode = $cb->addSubtree($dbNode, 'Data_Files', $dfParam );

            foreach my $dfName ( keys %{ $db->{'oraDbDataFile'} } )
            {
                my $INDEX = $db->{'oraDbDataFile'}->{$dfName};

                my $nick = $dfName;
                $nick =~ s/^\///;
                $nick =~ s/\W/_/g;
                $nick =~ s/_+/_/g;

                my $title = '%system-id%' . " $dbName $dfName";


                my $dfParam = {
                    'comment'   => "Data File: $dfName",
                    'precedence' => sprintf("%d", 10000 - $INDEX),
                    'data-file-nick' => $nick,
                    'data-file-name' => $dfName,
                    'graph-title' => $title,
                    'dbBlockSize' => $dbBlockSize,
                };

                $cb->addSubtree( $dfNode, $nick, $dfParam,
                                 ['OracleDatabase::data-file' ] );
                Debug("Will add DataFile: $dfName");
            }
        }

        if( $devdetails->hasCap('oraDbLibraryCache') )
        {
            my $lcParam = {
                'comment' => "Library Cache for $dbName",
                'precedence' => "400",
            };

            my $lcNode = $cb->addSubtree($dbNode, 'Library_Cache', $lcParam );

            foreach my $lcName ( keys %{ $db->{'oraDbLibraryCache'} } )
            {
                my $INDEX = $db->{'oraDbLibraryCache'}->{$lcName};

                my $nick = $lcName;
                $nick =~ s/^\///;
                $nick =~ s/\W/_/g;
                $nick =~ s/_+/_/g;

                my $title = '%system-id%' . " $dbName $lcName";

                my $lcParam = {
                    'comment'   => "Library Cache: $lcName",
                    'precedence' => sprintf("%d", 10000 - $INDEX),
                    'library-cache-nick' => $nick,
                    'library-cache-name' => $lcName,
                    'graph-title' => $title,
                };

                $cb->addSubtree( $lcNode, $nick, $lcParam,
                                 ['OracleDatabase::library-cache'] );
                Debug("Will add LibraryCache: $lcName");
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
