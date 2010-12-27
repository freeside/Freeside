#
#    Copyright (C) 1998 Jeff R. Allen and WebTV Networks, Inc.
#    Copyright (C) 2002  Stanislav Sinyagin
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

# $Id: RPN.pm,v 1.1 2010-12-27 00:03:40 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# a simple little RPN calculator -- implements the same operations
# that RRDTool does.

# This file is based on Cricket's RPM.pm

package Torrus::RPN;

use strict;

use Torrus::Log;
use Math::BigFloat;

# Each RPN operator is defined by an array reference with the
# following  elements: <number of args>, <subroutine>, <accepts undef>

my $operators = {
    '+' => [ 2, sub{ $_[0] + $_[1]; } ],
    '-' => [ 2, sub{ $_[0] - $_[1]; } ],
    '*' => [ 2, sub{ $_[0] * $_[1]; } ],
    '/' => [ 2, sub{ $_[0] / $_[1]; } ],
    '%' => [ 2, sub{ $_[0] % $_[1]; } ],
    'MOD' => [ 2, sub{ $_[0] % $_[1]; } ],
    'SIN' => [ 1, sub{ sin($_[0]->bsstr()); } ],
    'COS' => [ 1, sub{ cos($_[0]->bsstr()); } ],
    'LOG' => [ 1, sub{ log($_[0]); } ],
    'EXP' => [ 1, sub{ $_[0]->exponent() } ],
    'FLOOR' => [ 1, sub{ $_[0]->bfloor(); } ],
    'CEIL' => [ 1, sub{ $_[0]->bceil(); } ],
    'LT' => [ 2, sub{ ($_[0] <  $_[1]) ? 1:0; } ],
    'LE' => [ 2, sub{ ($_[0] <= $_[1]) ? 1:0; } ],
    'GT' => [ 2, sub{ ($_[0] >  $_[1]) ? 1:0; } ],
    'GE' => [ 2, sub{ ($_[0] >= $_[1]) ? 1:0; } ],
    'EQ' => [ 2, sub{ ($_[0] == $_[1]) ? 1:0; } ],
    'IF' => [ 3, sub{ defined($_[0]) ? ($_[0] ? $_[1] : $_[2]) : undef; }, 1],
    'MIN' => [ 2, sub{ ($_[0] <  $_[1]) ? $_[0] : $_[1]; } ],
    'MAX' => [ 2, sub{ ($_[0] >  $_[1]) ? $_[0] : $_[1]; } ],
    'UN'   => [ 1, sub{ defined($_[0]) ? $_[0]->is_nan() : 1; }, 1 ],
    'UNKN' => [ 0, sub{ undef; } ],
    # Operators not defined in RRDtool graph
    'NE'  => [ 2, sub{ ($_[0] != $_[1]) ? 1:0; } ],
    'AND' => [ 2, sub{ ($_[0] and $_[1]) ? 1:0; } ],
    'OR'  => [ 2, sub{ ($_[0] or $_[1]) ? 1:0; } ],
    'NOT' => [ 1, sub{ (not $_[0]) ? 1:0; } ],
    'ABS' => [ 1, sub{ abs($_[0]); } ],
    'NOW' => [ 0, sub{ time(); } ],
    'DUP' => [ 1, sub{ ($_[0], $_[0]);}, 1 ],
    'EXC' => [ 2, sub{ ($_[1], $_[0]); }, 1 ],
    'NUM' => [ 1, sub{ defined($_[0]) ? $_[0] : 0; }, 1 ],
    'INF' => [ 0, sub{ Math::BigFloat->binf(); } ],
    'NEGINF' => [ 0, sub{ Math::BigFloat->binf('-'); } ]
    };


sub new
{
    my $type = shift;
    my $self = {};
    bless( $self, $type );
    $self->{'stack'} = [];
    return $self;
}


sub operator
{
    my $self = shift;
    my $op = shift;

    my $n_args           = $operators->{$op}->[0];
    my $action           = $operators->{$op}->[1];
    my $acceptsUndefined = $operators->{$op}->[2];
    my @args = ();
    my $allDefined = 1;
    for( my $i = 0; $i < $n_args; $i++ )
    {
        my $arg = $self->popStack();
        if( defined( $arg ) or $acceptsUndefined )
        {
            push( @args, $arg );
        }
        else
        {
            $allDefined = 0;
        }
    }
    $self->pushStack( $allDefined ? &{$action}(reverse @args) : undef );
}


sub popStack
{
    my $self = shift;

    my $ret;
    if( scalar( @{$self->{'stack'}} ) == 0 )
    {
        Warn("Stack underflow");
    }
    else
    {
        $ret = pop( @{$self->{'stack'}} );
    }
    return $ret;
}


sub pushStack
{
    my $self = shift;
    my @items = @_;

    push( @{$self->{'stack'}}, @items );
}


sub translate
{
    my $self = shift;
    my $string = shift;
    my $callback = shift;

    # Debug("Translating RPN: $string");
    my $item;
    my @new_items;
    foreach $item ( split( /,/, $string ) )
    {
        if( $item =~ /^\{([^\}]*)\}$/ )
        {
            my $noderef = $1;
            my $timeoffset;
            if( $noderef =~ s/\(([^\)]+)\)// )
            {
               $timeoffset = $1;
            }
            my $value = &{$callback}( $noderef, $timeoffset );
            $value = 'UNKN' unless defined( $value );
            # Debug("$item translated into $value");
            $item = $value;
        }
        elsif( $item eq 'MOD' )
        {
            # In Torrus parameter value, percent sign is reserved for
            # parameter expansion. Rrdtool understands % only.
            $item = '%';
        }
        push( @new_items, $item );
    }

    $string = join( ',', @new_items );
    # Debug("RPN translated: $string");
    return $string;
}


sub run
{
    my $self = shift;
    my $string = shift;
    my $callback = shift;

    # Debug("Input RPN: $string");

    if( index( $string, '{' ) >= 0 )
    {
        $string = $self->translate( $string, $callback );
    }

    my $item;
    foreach $item ( split( /,/, $string ) )
    {
        if( ref( $operators->{$item} ) )
        {
            $self->operator($item);
        }
        else
        {
            $self->pushStack( Math::BigFloat->new($item) );
        }
    }
    
    my $retval = $self->popStack();
    # Debug("RPN result: $retval");
    return $retval;
}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
