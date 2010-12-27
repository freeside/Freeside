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

# $Id: SrvExport.pm,v 1.1 2010-12-27 00:03:59 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Class for Collector's external storage export data manipulation.

package Torrus::SQL::SrvExport;

use strict;

use Torrus::SQL;
use base 'Torrus::SQL';

use Torrus::Log;

# The name of the table and columns where the collector export is stored
# defaults configured in torrus-config.pl
our $tableName;
our %columns;

sub sqlInsertStatement
{
    return sprintf('INSERT INTO %s (%s,%s,%s,%s,%s) VALUES (?,?,?,?,?)',
                   $tableName,
                   $columns{'srv_date'},
                   $columns{'srv_time'},
                   $columns{'serviceid'},
                   $columns{'value'},
                   $columns{'intvl'});
}
                   

sub getServiceIDs
{
    my $self = shift;
    
    $self->{'sql'}->select({
        'fields' => [ $columns{'serviceid'} ],
        'table' => $tableName,
        'group' => [ $columns{'serviceid'} ],
        'order' => [ $columns{'serviceid'} ] });

    my $ret = [];
    while( defined( my $row = $self->{'sql'}->fetchrow_arrayref() ) )
    {
        push( @{$ret}, $row->[0] );
    }

    return $ret;    
}    


# YYYY-MM-DD for start and end date
# returns the reference to the array of hashes for selected entries.

sub getIntervalData
{
    my $self = shift;
    my $startdate = shift;
    my $enddate = shift;
    my $serviceid = shift;

    $self->{'sql'}->select({
        'fields' =>
            [ $columns{'srv_date'},
              $columns{'srv_time'},
              $columns{'value'},
              $columns{'intvl'} ],
            'table' => $tableName,
            'where' => [ {$columns{'serviceid'} => $serviceid},
                         'AND',
                         {$columns{'srv_date'} => ['>=', $startdate]},
                         'AND',
                         {$columns{'srv_date'} => ['<', $enddate]}
                         ]});

    return $self->fetchall([ 'srv_date', 'srv_time', 'value', 'intvl' ]);
}


    
    
    



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
