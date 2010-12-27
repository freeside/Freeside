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

# $Id: ApacheHandler.pm,v 1.1 2010-12-27 00:03:38 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Apache mod_perl handler. See http://perl.apache.org

package Torrus::ApacheHandler;

use strict;
use Apache;

use Torrus::CGI;

sub handler
{
    my $r = shift;

    my $q = CGI->new($r);
    Torrus::CGI->process( $q );
    
    return Apache::Constants::OK;    
}


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
