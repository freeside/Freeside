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

# $Id: Search.pm,v 1.1 2010-12-27 00:03:39 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


# Task scheduler runtime information. Quite basic statistics access.

package Torrus::Search;

use Torrus::DB;
use Torrus::Log;
use strict;


sub new
{
    my $self = {};
    my $class = shift;
    my %options = @_;
    bless $self, $class;

    %{$self->{'options'}} = %options;

    return $self;
}


sub openTree
{
    my $self = shift;
    my $tree = shift;

    my $db = new Torrus::DB
        ( 'searchwords',
          -Subdir => $tree,
          -Btree => 1,
          -Duplicates => 1,
          -WriteAccess => $self->{'options'}{'-WriteAccess'},
          -Truncate => $self->{'options'}{'-WriteAccess'} );

    $self->{'db_treewords'}{$tree} = $db;
}


sub closeTree
{
    my $self = shift;
    my $tree = shift;

    $self->{'db_treewords'}{$tree}->closeNow();
}


sub openGlobal
{
    my $self = shift;

    my $db = new Torrus::DB
        ( 'globsearchwords',
          -Btree => 1,
          -Duplicates => 1,
          -WriteAccess => $self->{'options'}{'-WriteAccess'},
          -Truncate => $self->{'options'}{'-WriteAccess'} );

    $self->{'db_globwords'} = $db;    
}


sub storeKeyword
{
    my $self = shift;
    my $tree = shift;
    my $keyword = lc( shift );
    my $path = shift;
    my $param = shift;

    my $val = $path;
    if( defined( $param ) )
    {
        $val .= ':' . $param;
    }

    my $lookupkey = join( ':', $tree, $keyword, $val );    
    if( not $self->{'stored'}{$lookupkey} )
    {
        $self->{'db_treewords'}{$tree}->put( $keyword, $val );
        if( defined( $self->{'db_globwords'} ) )
        {
            $self->{'db_globwords'}->put( $keyword, join(':', $tree, $val) );
        }

        $self->{'stored'}{$lookupkey} = 1;
    }
}

sub searchPrefix
{
    my $self = shift;
    my $prefix = lc( shift );
    my $tree = shift;

    my $db = defined( $tree ) ?
        $self->{'db_treewords'}{$tree} : $self->{'db_globwords'};

    my $result = $db->searchPrefix( $prefix );

    my $ret = [];
    
    if( defined( $result ) )
    {
        foreach my $pair ( @{$result} )
        {
            my $retstrings = [];
            push( @{$retstrings}, split(':', $pair->[1]) );
            push( @{$ret}, $retstrings );
        }
    }

    return $ret;
}
    
    


    
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
