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

# $Id: DataAccess.pm,v 1.1 2010-12-27 00:03:39 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::DataAccess;

use Torrus::ConfigTree;
use Torrus::Log;
use Torrus::RPN;

use strict;
use RRDs;

# The Torrus::DataAccess object contains cached values, and it does not
# check the cache validity. We assume that a Torrus::DataAccess object
# lifetime is within a short period of time, such as one monitor cycle.

sub new
{
    my $self = {};
    my $class = shift;
    bless $self, $class;
    return $self;
}

# Read the data from datasource file, depending on its type.
# If time is not specified, reads the latest available data.
# In case of rrd-cdef leaf type, the returned timestamp is the
# earliest timestamp of the data sources involved.
#
# ($value, $timestamp) = $da->read( $config_tree, $leaf_token )
#
# ($value, $timestamp) = $da->read( $config_tree, $leaf_token, $end_time )
#
# ($value, $timestamp) = $da->read( $config_tree, $leaf_token,
#                                   $end_time, $start_time )


sub read
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $t_end = shift;
    my $t_start = shift;

    my $cachekey = $token .
        ':' . (defined($t_end)?$t_end:'') .
        ':' . (defined($t_start)?$t_start:'');
    
    if( exists( $self->{'cache_read'}{$cachekey} ) )
    {
        return @{$self->{'cache_read'}{$cachekey}};
    }
    
    if( not $config_tree->isLeaf( $token ) )
    {
        my $path = $config_tree->path( $token );
        Error("Torrus::DataAccess::readLast: $path is not a leaf");
        return undef;
    }

    my $ret_val;
    my $ret_time;
    
    my $ds_type = $config_tree->getNodeParam( $token, 'ds-type' );
    if( $ds_type eq 'rrd-file' or
        $ds_type eq 'collector' )
    {
        my $leaf_type = $config_tree->getNodeParam( $token, 'leaf-type' );

        if( $leaf_type eq 'rrd-def' )
        {
            my $file = $config_tree->getNodeParam( $token, 'data-file' );
            my $dir = $config_tree->getNodeParam( $token, 'data-dir' );
            my $ds = $config_tree->getNodeParam( $token, 'rrd-ds' );
            my $cf = $config_tree->getNodeParam( $token, 'rrd-cf' );
            ( $ret_val, $ret_time ) =
                $self->read_RRD_DS( $dir.'/'.$file,
                                    $cf, $ds, $t_end, $t_start );
        }
        elsif( $leaf_type eq 'rrd-cdef' )
        {
            my $expr = $config_tree->getNodeParam( $token, 'rpn-expr' );
            ( $ret_val, $ret_time ) =
                $self->read_RPN( $config_tree, $token, $expr,
                                 $t_end, $t_start );

        }
        else
        {
            my $path = $config_tree->path( $token );
            Error("$path: leaf-type $leaf_type is not supported ".
                  "for data access");
        }
    }
    else
    {
        my $path = $config_tree->path( $token );
        Error("$path: ds-type $ds_type is not supported ".
              "for data access");
    }
    
    $self->{'cache_read'}{$cachekey} = [ $ret_val, $ret_time ];
    return ( $ret_val, $ret_time );
}


sub read_RRD_DS
{
    my $self = shift;
    my $filename = shift;
    my $cf = shift;
    my $ds = shift;
    my $t_end = shift;
    my $t_start = shift;

    my $cachekey = $filename . ':' . $cf .
        ':' . (defined($t_end)?$t_end:'') .
        ':' . (defined($t_start)?$t_start:'');

    if( exists( $self->{'cache_RRD'}{$cachekey}{$ds} ) )
    {
        return @{$self->{'cache_RRD'}{$cachekey}{$ds}};
    }
                                         
    my $rrdinfo = RRDs::info( $filename );
    my $ERR = RRDs::error;
    if( $ERR )
    {
        Error("Error during RRD info for $filename: $ERR");
        return undef;

    }
    my $step = $rrdinfo->{'step'};
    my $last_available = $rrdinfo->{'last_update'};
    $last_available -= $last_available % $step;

    if( not defined $t_end )
    {
        $t_end = $last_available;
    }
    elsif( index( $t_end, 'LAST' ) >= 0 )
    {
        $t_end =~ s/LAST/$last_available/g;
    }

    if( not defined $t_start )
    {
        $t_start = $t_end . '-' . int($step * 3);
    }
    elsif( index( $t_start, 'LAST' ) >= 0 )
    {
        $t_start =~ s/LAST/$last_available/g;
    }

    # From here on, f_ prefix means fetch results
    my( $f_start, $f_step, $f_names, $f_data ) =
        RRDs::fetch( $filename, $cf, '--start', $t_start, '--end', $t_end );
    $ERR = RRDs::error;
    if( $ERR )
    {
        Error("Error during RRD fetch for $filename: $ERR");
        return undef;

    }

    # Memorize the DS names in cache
    
    for( my $i = 0; $i < @{$f_names}; $i++ )
    {
        $self->{'cache_RRD'}{$cachekey}{$f_names->[$i]} = [];
    }
    
    # Get the last available data and store in cache
    
    foreach my $f_line ( @{$f_data} )
    {
        for( my $i = 0; $i < @{$f_names}; $i++ )
        {
            if( defined $f_line->[$i] )
            {
                $self->{'cache_RRD'}{$cachekey}{$f_names->[$i]} =
                    [ $f_line->[$i], $f_start ];
            }
        }
        $f_start += $f_step;
    }
    
    if( not exists( $self->{'cache_RRD'}{$cachekey}{$ds} ) )
    {
        Error("DS name $ds is not found in $filename");
        return undef;
    }
    else
    {
        if( scalar( @{$self->{'cache_RRD'}{$cachekey}{$ds}} ) == 0 )
        {
            Warn("Value undefined for ",
                 "DS=$ds, CF=$cf, start=$t_start, end=$t_end in $filename");
            return undef;
        }
        else
        {
            return @{$self->{'cache_RRD'}{$cachekey}{$ds}};
        }
    }
}



# Data access for other CF than defined for the leaf doesn't make much
# sense. So we ignore the CF in DataAccess and leave it for the
# sake of Renderer compatibility
my %cfNames =
    ( 'AVERAGE' => 1,
      'MIN'     => 1,
      'MAX'     => 1,
      'LAST'    => 1 );


sub read_RPN
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $expr = shift;
    my $t_end = shift;
    my $t_start = shift;

    my @expr_list = split(',', $expr);
    my @eval_expr;
    my $timestamp = $t_end > 0 ? $t_end : time();

    my $rpn = new Torrus::RPN;

    my $callback = sub
    {
        my ($noderef, $timeoffset) = @_;

        my $function;
        if( $noderef =~ s/^(.)\@// )
        {
            $function = $1;
        }

        my $leaf = length($noderef) > 0 ?
            $config_tree->getRelative($token, $noderef) : $token;

        if( not defined $leaf )
        {
            my $path = $config_tree->path($token);
            Error("Cannot find relative reference $noderef at $path");
            return undef;
        }

        my ($rval, $var_tstamp) = $self->read($config_tree,
                                              $leaf,
                                              $timeoffset,
                                              $t_start);
        if( defined $rval )
        {
            if( $var_tstamp == 0 )
            {
                Warn("Torrus::DataAccess::read retirned zero timestamp ".
                     "for $leaf");
            }

            if( $var_tstamp < $timestamp )
            {
                $timestamp = $var_tstamp;
            }
        }

        if( defined( $function ) )
        {
            if( $function eq 'T' )
            {
                return $var_tstamp;
            }
            elsif( not $cfNames{$function} )
            {
                Error("Function not supported in RPN: $function");
                return undef;
            }
        }
        return $rval;
    };

    my $result = $rpn->run( $expr, $callback );

    return ( $result, $timestamp );
}

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
