#  Copyright (C) 2010  Stanislav Sinyagin
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

# $Id: SNMP_Failures.pm,v 1.1 2010-12-27 00:03:39 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


# SNMP failures statistics interface

package Torrus::SNMP_Failures;

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

    die() if ( not defined($options{'-Tree'}) or
               not defined($options{'-Instance'}) );

    $self->{'db_failures'} =
        new Torrus::DB( 'snmp_failures_' . $options{'-Instance'},
                        -Subdir => $self->{'options'}{'-Tree'},
                        -Btree => 1,
                        -WriteAccess => $options{'-WriteAccess'} );

    $self->{'counters'} = ['unreachable', 'deleted', 'mib_errors'];
    
    return( defined( $self->{'db_failures'} ) ? $self:undef );
}


sub DESTROY
{
    my $self = shift;    
    $self->{'db_failures'}->closeNow();
}



sub init
{
    my $self = shift;

    $self->{'db_failures'}->trunc();
    
    foreach my $c ( @{$self->{'counters'}} )
    {
        $self->{'db_failures'}->put('c:' . $c, 0);
    }
}



sub host_failure
{
    my $self = shift;    
    my $type = shift;
    my $hosthash = shift;

    $self->{'db_failures'}->put('h:' . $hosthash,
                                $type . ':' . time());
}


sub set_counter
{
    my $self = shift;    
    my $type = shift;
    my $count = shift;

    $self->{'db_failures'}->put('c:' . $type, $count);
}
    

sub remove_host
{
    my $self = shift;    
    my $hosthash = shift;

    $self->{'db_failures'}->del('h:' . $hosthash);
}

    
sub mib_error
{
    my $self = shift;    
    my $hosthash = shift;
    my $path = shift;

    my $count = $self->{'db_failures'}->get('M:' . $hosthash);
    $count = 0 unless defined($count);

    $self->{'db_failures'}->put('m:' . $hosthash, $path . ':' . time());    
    $self->{'db_failures'}->put('M:' . $hosthash, $count + 1);

    my $global_count = $self->{'db_failures'}->get('c:mib_errors');
    $self->{'db_failures'}->put('c:mib_errors', $global_count + 1);
}



sub read
{
    my $self = shift;
    my $out = shift;
    my %options = @_;

    foreach my $c ( @{$self->{'counters'}} )
    {
        if( not defined( $out->{'total_' . $c} ) )
        {
            $out->{'total_' . $c} = 0;
        }
        
        $out->{'total_' . $c} += 
            $self->{'db_failures'}->get('c:' . $c);

        if( $options{'-details'} and
            not defined( $out->{'detail_' . $c} ) )
        {
            $out->{'detail_' . $c} = {};
        }
    }

    &Torrus::DB::checkInterrupted();
        
    if( $options{'-details'} )
    {
        my $cursor = $self->{'db_failures'}->cursor();
        while( my ($key, $val) = $self->{'db_failures'}->next($cursor) )
        {
            if( $key =~ /^h:(.+)$/o )
            {
                my $hosthash = $1;
                my ($counter, $timestamp) = split(/:/o, $val);

                $out->{'detail_' . $counter}{$hosthash} = {
                    'timestamp' => 0 + $timestamp,
                    'time' => scalar(localtime( $timestamp )),
                };
            }
            elsif( $key =~ /^m:(.+)$/o )
            {
                my $hosthash = $1;
                my ($path, $timestamp) = split(/:/o, $val);

                $out->{'detail_mib_errors'}{$hosthash}{'nodes'}{$path} = {
                    'timestamp' => 0 + $timestamp,
                    'time' => scalar(localtime( $timestamp )),
                }
            }
            elsif( $key =~ /^M:(.+)$/o )
            {
                my $hosthash = $1;
                my $count = 0 + $val;
                
                if( not defined
                    ( $out->{'detail_mib_errors'}{$hosthash}{'count'}) )
                {
                    $out->{'detail_mib_errors'}{$hosthash}{'count'} = 0;
                }
                
                $out->{'detail_mib_errors'}{$hosthash}{'count'} += $count;
            }
            
            &Torrus::DB::checkInterrupted();
        }
        
        undef $cursor;
    }
}




1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
