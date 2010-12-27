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

# $Id: SchedulerInfo.pm,v 1.1 2010-12-27 00:03:43 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


# Task scheduler runtime information. Quite basic statistics access.

package Torrus::SchedulerInfo;

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

    die() if not defined( $options{'-Tree'} );

    $self->{'db_stats'} =
        new Torrus::DB( 'scheduler_stats',
                      -Subdir => $self->{'options'}{'-Tree'},
                      -Btree => 1,
                      -WriteAccess => $options{'-WriteAccess'} );

    return( defined( $self->{'db_stats'} ) ? $self:undef );
}


sub DESTROY
{
    my $self = shift;
    delete $self->{'db_stats'};
}


sub readStats
{
    my $self = shift;

    my $stats = {};

    my $cursor = $self->{'db_stats'}->cursor();
    while( my ($key, $value) = $self->{'db_stats'}->next($cursor) )
    {
        my( $id, $variable ) = split( '#', $key );
        if( defined( $id ) and defined( $variable ) )
        {
            $stats->{$id}{$variable} = $value;
        }
    }
    undef $cursor;

    return $stats;
}


sub setValue
{
    my $self = shift;
    my $id = shift;
    my $variable = shift;
    my $value = shift;

    $self->{'db_stats'}->put( join('#', $id, $variable), $value );
}

sub getValue
{
    my $self = shift;
    my $id = shift;
    my $variable = shift;
    
    return $self->{'db_stats'}->get( join('#', $id, $variable) );
}


sub clearStats
{
    my $self = shift;
    my $id = shift;

    my $cursor = $self->{'db_stats'}->cursor( -Write => 1 );
    while( my ($key, $value) = $self->{'db_stats'}->next($cursor) )
    {
        my( $db_id, $variable ) = split( '#', $key );
        if( defined( $db_id ) and defined( $variable ) and
            $id eq $db_id )
        {
            $self->{'db_stats'}->c_del( $cursor );
        }
    }
    undef $cursor;
}


sub clearAll
{
    my $self = shift;
    $self->{'db_stats'}->trunc();
}


sub setStatsValues
{
    my $self = shift;
    my $id = shift;
    my $variable = shift;
    my $value = shift;

    $self->setValue( $id, 'Last' . $variable, $value );

    my $maxName = 'Max' . $variable;
    my $maxVal = $self->getValue( $id, $maxName );
    if( not defined( $maxVal ) or $value > $maxVal )
    {
        $maxVal = $value;
    }
    $self->setValue( $id, $maxName, $maxVal );

    my $minName = 'Min' . $variable;
    my $minVal = $self->getValue( $id, $minName );
    if( not defined( $minVal ) or $value < $minVal )
    {
        $minVal = $value;
    }
    $self->setValue( $id, $minName, $minVal );

    my $timesName = 'NTimes' . $variable;
    my $nTimes = $self->getValue( $id, $timesName );

    my $avgName = 'Avg' . $variable;
    my $average = $self->getValue( $id, $avgName );

    if( not defined( $nTimes ) )
    {
        $nTimes = 1;
        $average = $value;
    }
    else
    {
        $average = ( $average * $nTimes + $value ) / ( $nTimes + 1 );
        $nTimes++;
    }
    $self->setValue( $id, $timesName, $nTimes );
    $self->setValue( $id, $avgName, $average );

    my $expAvgName = 'ExpAvg' . $variable;
    my $expAverage = $self->getValue( $id, $expAvgName );
    if( not defined( $expAverage ) )
    {
        $expAverage = $value;
    }
    else
    {
        my $alpha = $Torrus::Scheduler::statsExpDecayAlpha;
        $expAverage = $alpha * $value + ( 1 - $alpha ) * $expAverage;
    }
    $self->setValue( $id, $expAvgName, $expAverage );
}


sub incStatsCounter
{
    my $self = shift;
    my $id = shift;
    my $variable = shift;
    my $increment = shift;

    if( not defined( $increment ) )
    {
        $increment = 1;
    }

    my $name = 'Count' . $variable;
    my $previous = $self->getValue( $id, $name );

    if( not defined( $previous ) )
    {
        $previous = 0;
    }
    
    $self->setValue( $id, $name, $previous + $increment );
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
