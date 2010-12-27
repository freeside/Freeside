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

# $Id: AuthLocalMD5.pm,v 1.1 2010-12-27 00:03:59 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


package Torrus::ACL::AuthLocalMD5;

use Torrus::Log;

use Digest::MD5 qw(md5_hex);
use strict;

sub new
{
    my $self = {};
    my $class = shift;
    bless $self, $class;
    return $self;
}


sub getUserAttrList
{
    return qw(userPasswordMD5);
}

sub authenticateUser
{
    my $self = shift;
    my $uid = shift;
    my $password = shift;
    my $attrValues = shift;

    if( not $password or not $attrValues->{'userPasswordMD5'} )
    {
        return undef;
    }
    my $pw_md5 = md5_hex( $password );
    return( $pw_md5 eq $attrValues->{'userPasswordMD5'} );
}


sub setPassword
{
    my $self = shift;
    my $uid = shift;
    my $password = shift;

    my $attrValues = {};
    $attrValues->{'userPasswordMD5'} = md5_hex( $password );
    return $attrValues;
}




1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
