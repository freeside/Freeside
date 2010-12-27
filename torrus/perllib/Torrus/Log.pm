#    This file was initially taken from Cricket, and reworked later
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

# $Id: Log.pm,v 1.1 2010-12-27 00:03:43 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# 2002/06/25 11:35:00  ssinyagin
# Taken from Cricket lib/Common/Log.pm
#
# 2004/06/25 ssinyagin
# Finally reworked in 2 years!
#

package Torrus::Log;

use strict;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(Debug Warn Info Error Verbose isDebug);

my @monthNames = ( 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
                   'Aug', 'Sep', 'Oct', 'Nov', 'Dec' );

my %logLevel = (
                'debug'    => 9,
                'verbose'  => 8,
                'info'     => 7,
                'warn'     => 5,
                'error'    => 1 );

my $currentLogLevel = $logLevel{'info'};

sub Log
{
    my( $level, @msg ) = @_;    

    $level = $logLevel{$level};
    
    if( $level <= $currentLogLevel )
    {
        my $severity = ( $level <= $logLevel{'warn'} ) ? '*' : ' ';
        printf STDERR ( "[%s%s] %s\n",
                        timeStr( time() ), $severity, join( '', @msg ) );
    }
    return undef;
}


sub Error
{
    Log( 'error', @_ );
}

sub Warn
{
    Log( 'warn', @_);
}

sub Info
{
    Log( 'info', @_ );
}

sub Verbose
{
    Log( 'verbose', @_ );
}

our $TID = 0;
sub setTID
{
    $TID = shift;
}

sub Debug
{
    Log( 'debug', $$ . '.' . $TID . ' ', join('|', @_) );
}


sub isDebug
{
    return $currentLogLevel >= $logLevel{'debug'};
}

sub timeStr
{
    my $t = shift;
    
    my( $sec, $min, $hour, $mday, $mon, $year) = localtime( $t );
    
    return sprintf('%02d-%s-%04d %02d:%02d:%02d',
                   $mday, $monthNames[$mon], $year + 1900, $hour, $min, $sec);
}

sub setLevel
{
    my $level = lc( shift );

    if( defined( $logLevel{$level} ) )
    {
        $currentLogLevel = $logLevel{$level};
    }
    else
    {
        Error("Log level name '$level' unknown. Defaulting to 'info'");
        $currentLogLevel = $logLevel{'info'};
    }
}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 4
# perl-indent-level: 4
# End:
