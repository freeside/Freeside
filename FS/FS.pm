package FS;

use strict;
use vars qw($VERSION);

$VERSION = '0.01';

1;
__END__

=head1 NAME

FS - Freeside Perl modules

=head1 SYNOPSIS

FS is the unofficial (i.e. non-CPAN) prefix for the Perl module portion of the
Freeside ISP billing software.  This includes:

=head2 Utility classes

L<FS::Conf> - Freeside configuration values

L<FS::UID> - User class (not yet OO)

L<FS::CGI> - Non OO-subroutines for the web interface.  This is
depriciated.  Future development will be focused on the FS::UI user-interface
classes (see below).

=head2 Database record classes

L<FS::Record> - Database record base class

L<FS::svc_acct_pop> - POP (Point of Presence, not Post
Office Protocol) class

L<FS::part_referral> - Referral class

L<FS::cust_main_county> - Locale (tax rate) class

L<FS::svc_Common> - Service base class

L<FS::svc_acct> - Account (shell, RADIUS, POP3) class

L<FS::svc_domain> - Domain class

L<FS::svc_acct_sm> - Vitual mail alias class

L<FS::part_svc> - Service definition class

L<FS::part_pkg> - Package (billing item) definition class

L<FS::pkg_svc> - Class linking package (billing item)
definitions (see L<FS::part_pkg>) with service definitions
(see L<FS::part_svc>)

L<FS::agent> - Agent (reseller) class

L<FS::agent_type> - Agent type class

L<FS::type_pkgs> - Class linking agent types (see
L<FS::agent_type>) with package (billing item) definitions
(see L<FS::part_pkg>)

L<FS::cust_svc> - Service class

L<FS::cust_pkg> - Package (billing item) class

L<FS::cust_main> - Customer class

L<FS::cust_main_invoice> - Invoice destination
class

L<FS::cust_bill> - Invoice class

L<FS::cust_bill_pkg> - Invoice line item class

L<FS::cust_pay> - Payment class

L<FS::cust_credit> - Credit class

L<FS::cust_refund> - Refund class

L<FS::cust_pay_batch> - Credit card transaction queue
class

=head2 User Interface classes (under development; not yet usable)

L<FS::UI::Base> - User-interface base class

L<FS::UI::Gtk> - Gtk user-interface class

L<FS::UI::CGI> - CGI (HTML) user-interface class

L<FS::UI::agent> - agent table user-interface class

=head2 Notes

To quote perl(1), "If you're intending to read these straight through for the
first time, the suggested order will tend to reduce the number of forward
references."

=head1 DESCRIPTION

Freeside is a billing and administration package for Internet Service
Providers.

The Freeside home page is at <http://www.sisd.com/freeside>.

The main documentation is in htdocs/docs.

=head1 VERSION

$Id: FS.pm,v 1.4 2001-04-22 01:56:14 ivan Exp $

=head1 SUPPORT

A mailing list for users and developers is available.  Send a blank message to
<ivan-freeside-subscribe@sisd.com> to subscribe.

Commercial support is available; see
<http://www.sisd.com/freeside/commercial.html>.

=head1 AUTHOR

Primarily Ivan Kohler <ivan@sisd.com>, with help from many kind folks.

See the CREDITS file in the Freeside distribution for a (hopefully) complete
list and the individal files for details.

=head1 SEE ALSO

perl(1), main Freeside documentation in htdocs/docs/

=head1 BUGS

The version number of the FS Perl extension differs from the version of the
Freeside distribution, which are both different from the CVS version tag for
each file, which appears under the VERSION heading.

Those modules which would be useful separately should be pulled out, 
renamed appropriately and uploaded to CPAN.  So far: DBIx::DBSchema, Net::SSH
and Net::SCP...

=cut

