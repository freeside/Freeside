package FS;

use strict;
use vars qw($VERSION);

$VERSION = '0.01';

1;
__END__

=head1 NAME

FS - Freeside Perl modules

=head1 SYNOPSIS

FS is the temporary prefix for many disparate modules written for the Freeside
ISP billing software.  This includes:

=head2 Database metadata classes

=over 4

=item L<FS::dbdef|FS::dbdef> - Database class

=item L<FS::dbdef_table|FS::dbdef_table> - Database table class

=item L<FS::dbdef_column|FS::dbdef_column> - Database column class

=item L<FS::dbdef_colgroup|FS::dbdef_colgroup> - Database column group class

=item L<FS::dbdef_index|FS::dbdef_index> - Database index class

=item L<FS::dbdef_unique|FS::dbdef_unique> - Database unique index class

=back

=head2 Utility classes

=over 4

=item L<FS::SSH|FS::SSH> - Simple wrappers around ssh and scp commands.

=item L<FS::Conf|FS::Conf> - Freeside configuration values

=item L<FS::UID|FS::UID> - User class (not yet OO)

=item L<FS::CGI|FS::CGI> - Non OO-subroutines for the web interface.  This is
depriciated.  Future development will be focused on the FS::UI user-interface
classes (see below).

=back

=head2 Database record classes

=over 4

=item L<FS::Record|FS::Record> - Database record base class

=item L<FS::svc_acct_pop|FS::svc_acct_pop> - POP (Point of Presence, not Post
Office Protocol) class

=item L<FS::part_referral|FS::part_referral> - Referral class

=item L<FS::cust_main_county|FS::cust_main_county> - Locale (tax rate) class

=item L<FS::svc_Common|FS::svc_Common> - Service base class

=item L<FS::svc_acct|FS::svc_acct> - Account (shell, RADIUS, POP3) class

=item L<FS::svc_domain|FS::svc_domain> - Domain class

=item L<FS::svc_acct_sm|FS::svc_acct_sm> - Vitual mail alias class

=item L<FS::part_svc|FS::part_svc> - Service definition class

=item L<FS::part_pkg|FS::part_pkg> - Package (billing item) definition class

=item L<FS::pkg_svc|FS::pkg_svc> - Class linking package (billing item)
definitions (see L<FS::part_pkg>) with service definitions
(see L<FS::part_svc>)

=item L<FS::agent|FS::agent> - Agent (reseller) class

=item L<FS::agent_type|FS::agent_type> - Agent type class

=item L<FS::type_pkgs|FS::type_pkgs> - Class linking agent types (see
L<FS::agent_type>) with package (billing item) definitions
(see L<FS::part_pkg>)

=item L<FS::cust_svc|FS::cust_svc> - Service class

=item L<FS::cust_pkg|FS::cust_pkg> - Package (billing item) class

=item L<FS::cust_main|FS::cust_main> - Customer class

=item L<FS::cust_main_invoice|FS::cust_main_invoice> - Invoice destination
class

=item L<FS::cust_bill|FS::cust_bill> - Invoice class

=item L<FS::cust_bill_pkg|FS::cust_bill_pkg> - Invoice line item class

=item L<FS::cust_pay|FS::cust_pay> - Payment class

=item L<FS::cust_credit|FS::cust_credit> - Credit class

=item L<FS::cust_refund|FS::cust_refund> - Refund class

=item L<FS::cust_pay_batch|FS::cust_pay_batch> - Credit card transaction queue
class

=back

=head2 User Interface classes (under development; not yet usable)

=over 4

=item L<FS::UI::Base|FS::UI::Base> - User-interface base class

=item L<FS::UI::Gtk|FS::UI::Gtk> - Gtk user-interface class

=item L<FS::UI::CGI|FS::UI::CGI> - CGI (HTML) user-interface class

=item L<FS::UI::agent|FS::UI::agent> - agent table user-interface class

=back

To quote perl(1), "If you're intending to read these straight through for the
first time, the suggested order will tend to reduce the number of forward
references."

=head1 DESCRIPTION

Freeside is a billing and administration package for Internet Service
Providers.

The Freeside home page is at <http://www.sisd.com/freeside>.

The main documentation is in htdocs/docs.

=head1 VERSION

$Id: FS.pm,v 1.2 1999-08-04 07:34:15 ivan Exp $

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
renamed appropriately and uploaded to CPAN.

=cut

