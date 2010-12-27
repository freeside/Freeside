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

# $Id: SQL.pm,v 1.1 2010-12-27 00:03:38 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Package for RDBMS communication management in Torrus
# Classes should inherit Torrus::SQL and execute Torrus::SQL->new(),
# and then use methods of DBIx::Abstract.

package Torrus::SQL;

use strict;
use DBI;
use DBIx::Abstract;
use DBIx::Sequence;

use Torrus::Log;

my %connectionArgsCache;

# Obtain connection attributes for particular class and object subtype.
# The attributes are defined in torrus-siteconfig.pl, in a hash
# %Torrus::SQL::connections.
# For a given Perl class and an optional subtype,
# the connection attributes are derived in the following order:
# 'Default', 'Default/[subtype]', '[Class]', '[Class]/[subtype]',
# 'All/[subtype]'.
# For a simple setup, the default attributes are usually defined for
# 'Default' key.
# The key attributes are: 'dsn', 'username', and 'password'.
# Returns a hash reference with the same keys.

sub getConnectionArgs
{
    my $class = shift;
    my $objClass = shift;
    my $subtype = shift;

    my $cachekey = $objClass . ( defined( $subtype )? '/'.$subtype : '');
    if( defined( $connectionArgsCache{$cachekey} ) )
    {
        return $connectionArgsCache{$cachekey};
    }
    
    my @lookup = ('Default');
    if( defined( $subtype ) )
    {
        push( @lookup, 'Default/' . $subtype );
    }
    push( @lookup, $objClass );
    if( defined( $subtype ) )
    {
        push( @lookup, $objClass . '/' . $subtype, 'All/' . $subtype );
    }    

    my $ret = {};
    foreach my $attr ( 'dsn', 'username', 'password' )
    {
        my $val;
        foreach my $key ( @lookup )
        {
            if( defined( $Torrus::SQL::connections{$key} ) )
            {
                if( defined( $Torrus::SQL::connections{$key}{$attr} ) )
                {
                    $val = $Torrus::SQL::connections{$key}{$attr};
                }
            }
        }
        if( not defined( $val ) )
        {
            die('Undefined attribute in %Torrus::SQL::connections: ' . $attr);
        }
        $ret->{$attr} = $val;
    }

    $connectionArgsCache{$cachekey} = $ret;
    
    return $ret;
}


my %dbhPool;

# For those who want direct DBI manipulation, simply call
# Class->dbh($subtype) with optional subtype. Then you don't use
# any other methods of Torrus::SQL.

sub dbh
{
    my $class = shift;
    my $subtype = shift;

    my $attrs = Torrus::SQL->getConnectionArgs( $class, $subtype );

    my $poolkey = $attrs->{'dsn'} . '//' . $attrs->{'username'} . '//' .
        $attrs->{'password'};

    my $dbh;
    
    if( exists( $dbhPool{$poolkey} ) )
    {
        $dbh = $dbhPool{$poolkey};
        if( not $dbh->ping() )
        {
            $dbh = undef;
            delete $dbhPool{$poolkey};
        }
    }

    if( not defined( $dbh ) )
    {
        $dbh = DBI->connect( $attrs->{'dsn'},
                             $attrs->{'username'},
                             $attrs->{'password'},
                             { 'PrintError' => 0,
                               'AutoCommit' => 0 } );

        if( not defined( $dbh ) )
        {
            Error('Error connecting to DBI source ' . $attrs->{'dsn'} . ': ' .
                  $DBI::errstr);
        }
        else
        {
            $dbhPool{$poolkey} = $dbh;
        }
    }
    
    return $dbh;
}


END
{
    foreach my $dbh ( values %dbhPool )
    {
        $dbh->disconnect();
    }
}


sub new
{
    my $class = shift;
    my $subtype = shift;

    my $self = {};

    $self->{'dbh'} = $class->dbh( $subtype );
    if( not defined( $self->{'dbh'} ) )
    {
        return undef;
    }
    
    $self->{'sql'} = DBIx::Abstract->connect( $self->{'dbh'} );

    $self->{'subtype'} = $subtype;
    $self->{'classname'} = $class;
    
    bless ($self, $class);
    return $self;    
}



sub sequence
{
    my $self = shift;

    if( not defined( $self->{'sequence'} ) )
    {
        my $attrs = Torrus::SQL->getConnectionArgs( $self->{'classname'},
                                                    $self->{'subtype'} );

        $self->{'sequence'} = DBIx::Sequence->new({
            dbh => $self->{'dbh'},
            allow_id_reuse => 1 });
    }
    return $self->{'sequence'};
}
       

sub sequenceNext
{
    my $self = shift;

    return $self->sequence()->Next($self->{'classname'});
}


sub fetchall
{
    my $self = shift;
    my $columns = shift;
    
    my $ret = [];
    while( defined( my $row = $self->{'sql'}->fetchrow_arrayref() ) )
    {
        my $retrecord = {};
        my $i = 0;
        foreach my $col ( @{$columns} )
        {
            $retrecord->{$col} = $row->[$i++];
        }
        push( @{$ret}, $retrecord );
    }
    
    return $ret;
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
