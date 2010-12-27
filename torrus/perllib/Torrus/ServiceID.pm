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

# $Id: ServiceID.pm,v 1.1 2010-12-27 00:03:39 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Manage the properties assigned to Service IDs

package Torrus::ServiceID;

use Torrus::DB;
use Torrus::Log;

use strict;


sub new
{
    my $self = {};
    my $class = shift;
    my %options = @_;
    bless $self, $class;

    my $writing = $options{'-WriteAccess'};

    $self->{'db_params'} =
        new Torrus::DB( 'serviceid_params',
                        -Btree => 1,
                        -WriteAccess => $writing );
    defined( $self->{'db_params'} ) or return( undef );

    $self->{'is_writing'} = $writing;

    return $self;
}


sub DESTROY
{
    my $self = shift;
    Debug('Destroyed ServiceID object');
    undef $self->{'db_params'};
}



sub idExists
{
    my $self = shift;
    my $serviceid = shift;
    my $tree = shift;

    if( defined($tree) )
    {
        return $self->{'db_params'}->searchList( 't:'.$tree, $serviceid );
    }

    return $self->{'db_params'}->searchList( 'a:', $serviceid );
}    
    

sub add
{
    my $self = shift;
    my $serviceid = shift;
    my $parameters = shift;

    $self->{'db_params'}->addToList( 'a:', $serviceid );
    
    my $trees = $parameters->{'trees'};

    foreach my $tree ( split(/\s*,\s*/o, $trees) )
    {
        $self->{'db_params'}->addToList( 't:'.$tree, $serviceid );
    }

    foreach my $param ( keys %{$parameters} )
    {
        my $val = $parameters->{$param};
        
        if( defined( $val ) and length( $val ) > 0 )
        {
            $self->{'db_params'}->put( 'p:'.$serviceid.':'.$param, $val );
            $self->{'db_params'}->addToList( 'P:'.$serviceid, $param );
        }
    }
}


sub getParams
{
    my $self = shift;
    my $serviceid = shift;

    my $ret = {};
    my $plist = $self->{'db_params'}->get( 'P:'.$serviceid );
    foreach my $param ( split(',', $plist ) )
    {
        $ret->{$param} =
            $self->{'db_params'}->get( 'p:'.$serviceid.':'.$param );
    }

    return $ret;
}    


sub getAllForTree
{
    my $self = shift;
    my $tree = shift;

    my $ret = [];
    my $idlist = $self->{'db_params'}->get('t:'.$tree);
    if( defined( $idlist ) )
    {
        push( @{$ret}, split( ',', $idlist ) );
    }
    return $ret;
}


sub cleanAllForTree
{
    my $self = shift;
    my $tree = shift;

    my $idlist = $self->{'db_params'}->get('t:'.$tree);
    if( defined( $idlist ) )
    {
        foreach my $serviceid ( split( ',', $idlist ) )
        {
            # A ServiceID may belong to several trees.
            # delete it from all other trees.

            my $srvTrees =
                $self->{'db_params'}->get( 'p:'.$serviceid.':trees' );
            
            foreach my $srvTree ( split(/\s*,\s*/o, $srvTrees) )
            {
                if( $srvTree ne $tree )
                {
                    $self->{'db_params'}->delFromList( 't:'.$srvTree,
                                                       $serviceid );
                }
            }            
            
            $self->{'db_params'}->delFromList( 'a:', $serviceid );
            
            my $plist = $self->{'db_params'}->get( 'P:'.$serviceid );

            foreach my $param ( split(',', $plist ) )
            {
                $self->{'db_params'}->del( 'p:'.$serviceid.':'.$param );
            }

            $self->{'db_params'}->del( 'P:'.$serviceid );
            
        }
        $self->{'db_params'}->deleteList('t:'.$tree);
    }
}

            
            
            
            

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
