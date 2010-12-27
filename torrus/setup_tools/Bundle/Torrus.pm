#  Torrus Perl bundle
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

# $Id: Torrus.pm,v 1.1 2010-12-27 00:04:39 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>
#
#


package Bundle::Torrus;

$VERSION = '1.00';

__END__

=head1 NAME

Bundle::Torrus - A bundle to install Torrus prerequisite modules

=head1 SYNOPSIS

C<perl -I `pwd`/lib -MCPAN -e 'install Bundle::Torrus'>

=head1 CONTENTS

File::Temp                       - required by XML::SAX

XML::NamespaceSupport   1.07     - required by XML::LibXML

XML::SAX                0.11     - required by XML::LibXML

XML::LibXML::Common              - required by XML::LibXML

AppConfig               - required by Template

File::Spec              - required by Template

Crypt::DES     2.03     - required by Net::SNMP

Digest::MD5    2.11     - required by Net::SNMP

Digest::SHA1   1.02     - required by Net::SNMP

Digest::HMAC   1.00     - required by Net::SNMP

MIME::Base64            - required by URI::Escape


XML::LibXML     1.54  - older versions do not handle charsets properly

BerkeleyDB      0.19    - older versions do not have trunc()

Template                - this is template-toolkit

Proc::Daemon

Net::SNMP       5.2.0   - older versions may not work

URI::Escape

Apache::Session

Date::Parse

JSON

=head1 AUTHOR

Stanislav Sinyagin E<lt>F<ssinyagin@yahoo.com>E<gt>

=cut
