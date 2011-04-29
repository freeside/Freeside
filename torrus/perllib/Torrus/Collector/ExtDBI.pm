#  Copyright (C) 2005  Stanislav Sinyagin
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

# $Id: ExtDBI.pm,v 1.2 2011-04-29 01:13:20 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

## Pluggable backend module for ExternalStorage
## Stores data in a generic SQL database

# We use some internals of Torrus::SQL::SrvExport, but
# handle the SQL by ourselves, for better efficiency.

package Torrus::Collector::ExtDBI;

use strict;
use DBI;
use Date::Format;

use Torrus::SQL::SrvExport;
use Torrus::Log;

$Torrus::Collector::ExternalStorage::backendInit =
    \&Torrus::Collector::ExtDBI::backendInit;

$Torrus::Collector::ExternalStorage::backendOpenSession =
    \&Torrus::Collector::ExtDBI::backendOpenSession;

$Torrus::Collector::ExternalStorage::backendStoreData =
    \&Torrus::Collector::ExtDBI::backendStoreData;

$Torrus::Collector::ExternalStorage::backendCloseSession =
    \&Torrus::Collector::ExtDBI::backendCloseSession;


# Optional SQL connection subtype, configurable from torrus-siteconfig.pl
our $subtype;

my $dbh;
my $sth;

sub backendInit
{
    my $collector = shift;
    my $token = shift;
}

sub backendOpenSession
{
    $dbh = Torrus::SQL::SrvExport->dbh( $subtype );
    
    if( defined( $dbh ) )
    {

        if ( $dbh->{Driver}->{Name} =~ /^mysql/i ) {
          $dbh->do('SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED');
          $dbh->commit();
        }

        $sth = $dbh->prepare( Torrus::SQL::SrvExport->sqlInsertStatement() );
        if( not defined( $sth ) )
        {
            Error('Error preparing the SQL statement: ' . $dbh->errstr);
        }
    }
}


sub backendStoreData
{
    my $timestamp = shift;
    my $serviceid = shift;
    my $value = shift;
    my $interval = shift;
    
    if( defined( $dbh ) and defined( $sth ) )
    {
        my $datestr = time2str('%Y-%m-%d', $timestamp);
        my $timestr = time2str('%H:%M:%S', $timestamp);
        if( isDebug() )
        {
            Debug('Updating SQL database: ' .
                  join(', ', $datestr, $timestr,
                       $serviceid, $value, $interval ));
        }

        if( $sth->execute( $datestr, $timestr,
                           $serviceid, $value, $interval ) )
        {
            return 1;
        }
        else
        {
            Error('Error executing SQL: ' . $dbh->errstr);
        }
    }

    return undef;
}


sub backendCloseSession
{
    undef $sth;
    if( defined( $dbh ) )
    {
        $dbh->commit();
        $dbh->disconnect();
        undef $dbh;
    }
}


    
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
