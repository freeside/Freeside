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

# $Id: Export.pm,v 1.1 2010-12-27 00:03:59 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


package Torrus::ACL::Export;

use Torrus::ACL;
use Torrus::ACL::Edit;
use Torrus::Log;

use Template;

use strict;


sub exportACL
{
    my $self = shift;
    my $exportfile = shift;
    my $exporttemplate = shift;

    my $tt = new Template(INCLUDE_PATH => $Torrus::Global::templateDirs,
                          TRIM => 1);

    my $vars = {
        'groups'      => sub { return $self->listGroups(); },
        'users'       => sub { return $self->listUsers(); },
        'memberof'    => sub { return $self->memberOf($_[0]); },
        'uattrlist'   => sub { return $self->listUserAttributes($_[0]); },
        'uattr'       => sub { return $self->userAttribute($_[0], $_[1]); },
        'gattrlist'   => sub { return $self->listGroupAttributes($_[0]); },
        'gattr'       => sub { return $self->groupAttribute($_[0], $_[1]); },
        'privileges'  => sub { return $self->listPrivileges($_[0]); },
        'version'    => $Torrus::Global::version,
        'xmlnorm'     => \&xmlnormalize
        };

    my $ok = $tt->process($exporttemplate, $vars, $exportfile);

    if( not $ok )
    {
        print STDERR "Error while processing template: ".$tt->error()."\n";
    }
    else
    {
        Info('Wrote ' . $exportfile);
    }

    return $ok;
}


sub xmlnormalize
{
    my( $txt )= @_;

    $txt =~ s/\&/\&amp\;/gm;
    $txt =~ s/\</\&lt\;/gm;
    $txt =~ s/\>/\&gt\;/gm;
    $txt =~ s/\'/\&apos\;/gm;
    $txt =~ s/\"/\&quot\;/gm;

    return $txt;
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
