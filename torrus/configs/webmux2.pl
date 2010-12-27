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

# $Id: webmux2.pl,v 1.1 2010-12-27 00:04:42 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Apache mod_perl initialisation

BEGIN { require '@torrus_config_pl@'; }

use Apache2::ServerUtil;
use mod_perl2;

use Torrus::Log;
use Torrus::DB;

# Probably we need MPM-specific Code here
# http://perl.apache.org/docs/2.0/user/coding/coding.html

# Tested with prefork MPM only.
# Threaded MPMs will not work because RRDtool is RRDs.pm is not
# currently thread safe


sub child_exit_handler
{
    my( $child_pool, $s ) = @_;
    Debug('Torrus child exit handler executed');
    Torrus::DB::cleanupEnvironment();
}


if( $Torrus::Renderer::globalDebug )
{
    &Torrus::Log::setLevel('debug');
}

my $ok = 1;
my $s = Apache2::ServerUtil->server();

# Apache::Server::is_perl_option_enabled is implemented since
# mod_perl2-1.99r13, but many installations still use mod_perl2-1.99r12
if( $mod_perl::VERSION > 1.9912 and
    not $s->is_perl_option_enabled('ChildExit') )
{
    $ok = 0;
    $s->log_error('ChildExit must be enabled for proper cleanup');
}
else
{
    $s->push_handlers( 'ChildExit' => \&child_exit_handler );
}


$ok;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
