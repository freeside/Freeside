package FS;

use strict;
use vars qw($VERSION);

$VERSION = '%%%VERSION%%%';

#find missing entries in this file with:
# for a in `ls *pm | cut -d. -f1`; do grep 'L<FS::'$a'>' ../FS.pm >/dev/null || echo "missing $a" ; done

1;
__END__

=head1 NAME

FS - Freeside Perl modules

=head1 SYNOPSIS

Freeside perl modules and CLI utilities.

=head2 Utility classes

L<FS::Conf> - Freeside configuration values

L<FS::ConfItem> - Freeside configuration option meta-data.

L<FS::UID> - User class (not yet OO)

L<FS::CGI> - Non OO-subroutines for the web interface.

L<FS::Msgcat> - Message catalog

L<FS::SearchCache> - Search cache

L<FS::raddb> - RADIUS dictionary

=head2 Database record classes

L<FS::Record> - Database record base class

L<FS::svc_acct_pop> - POP (Point of Presence, not Post
Office Protocol) class

L<FS::part_pop_local> - Local calling area class

L<FS::part_referral> - Referral class

L<FS::cust_main_county> - Locale (tax rate) class

L<FS::cust_tax_exempt> - Tax exemption record class

L<FS::svc_Common> - Service base class

L<FS::svc_acct> - Account (shell, RADIUS, POP3) class

L<FS::acct_snarf> - External mail account class

L<FS::radius_usergroup> - RADIUS groups

L<FS::svc_domain> - Domain class

L<FS::domain_record> - DNS zone entries

L<FS::svc_forward> - Mail forwarding class

L<FS::svc_www> - Web virtual host class.

L<FS::svc_broadband> - DSL, wireless and other broadband class.

L<FS::svc_external> - Externally tracked service class.

L<FS::part_svc> - Service definition class

L<FS::part_svc_column> - Column constraint class

L<FS::export_svc> - Class linking service definitions (see L<FS::part_svc>)
with exports (see L<FS::part_export>)

L<FS::part_export> - External provisioning export class

L<FS::part_export_option> - Export option class

L<FS::part_pkg> - Package definition class

L<FS::part_pkg_option> - Package definition option class

L<FS::pkg_svc> - Class linking package definitions (see L<FS::part_pkg>) with
service definitions (see L<FS::part_svc>)

L<FS::reg_code> - One-time registration codes

L<FS::reg_code_pkg> - Class linking registration codes (see L<FS::reg_code>) with package definitions (see L<FS::part_pkg>)

L<FS::rate> - Rate plans for call billing

L<FS::rate_region> - Rate regions for call billing

L<FS::rate_prefix> - Rate region prefixes for call billing

L<FS::rate_detail> - Rate plan detail for call billing

L<FS::agent> - Agent (reseller) class

L<FS::agent_type> - Agent type class

L<FS::type_pkgs> - Class linking agent types (see L<FS::agent_type>) with
package definitions (see L<FS::part_pkg>)

L<FS::cust_svc> - Service class

L<FS::cust_pkg> - Customer package class

L<FS::cust_pkg_option> - Customer package option class

L<FS::cust_main> - Customer class

L<FS::cust_main_invoice> - Invoice destination
class

L<FS::cust_bill> - Invoice class

L<FS::cust_bill_pkg> - Invoice line item class

L<FS::cust_bill_pkg_detail> - Invoice line item detail class

L<FS::part_bill_event> - Invoice event definition class

L<FS::cust_bill_event> - Completed invoice event class

L<FS::cust_pay> - Payment class

L<FS::cust_pay_void> - Voided payment class

L<FS::cust_bill_pay> - Payment application class

L<FS::cust_credit> - Credit class

L<FS::cust_refund> - Refund class

L<FS::cust_credit_refund> - Refund application to credit class

L<FS::cust_credit_bill> - Credit application to invoice class

L<FS::cust_pay_refund> - Refund application to payment class

L<FS::pay_batch> - Credit card transaction queue class

L<FS::cust_pay_batch> - Credit card transaction member queue class

L<FS::prepay_credit> - Prepaid "calling card" credit class.

L<FS::nas> - Network Access Server class

L<FS::port> - NAS port class

L<FS::session> - User login session class

L<FS::queue> - Job queue

L<FS::queue_arg> - Job arguments

L<FS::queue_depend> - Job dependencies

L<FS::msgcat> - Message catalogs

L<FS::clientapi_session>

L<FS::clientapi_session_field>

=head1 Client API

L<FS::ClientAPI>

L<FS::ClientAPI_SessionCache>

L<FS::ClientAPI::Signup>

L<FS::ClientAPI::passwd>

L<FS::ClientAPI::MyAccount>

L<FS::ClientAPI::Agent>

=head1 Remote API modules

L<FS::SelfService>

L<FS::SignupClient>

L<FS::SessionClient>

L<FS::MailAdminServer> (deprecated in favor of the self-service server)

=head2 Command-line utilities

L<freeside-adduser>

L<freeside-queued>

L<freeside-daily>

L<freeside-expiration-alerter>

L<freeside-email>

L<freeside-cc-receipts-report>

L<freeside-credit-report>

L<freeside-receivables-report>

L<freeside-tax-report>

L<freeside-bill>

L<freeside-overdue>

=head2 User Interface classes

L<FS::UI::Web> - Web user-interface class

=head2 Notes

To quote perl(1), "If you're intending to read these straight through for the
first time, the suggested order will tend to reduce the number of forward
references."

If you've never used OO modules before,
http://www.perl.com/doc/FMTEYEWTK/easy_objects.html might help you out.

=head1 DESCRIPTION

Freeside is a billing and administration package for Internet Service
Providers.

The Freeside home page is at <http://www.sisd.com/freeside>.

The main documentation is in httemplate/docs.

=head1 SUPPORT

A mailing list for users is available.  Send a blank message to
<freeside-users-subscribe@sisd.com> to subscribe.

A mailing list for developers is available.  It is intended to be lower volume
and higher SNR than the users list.  Send a blank message to
<freeside-devel-subscribe@sisd.com> to subscribe.

Commercial support is available; see
<http://www.sisd.com/freeside/commercial.html>.

=head1 AUTHOR

Primarily Ivan Kohler <ivan@sisd.com>, with help from many kind folks.

See the CREDITS file in the Freeside distribution for a (hopefully) complete
list and the individal files for details.

=head1 SEE ALSO

perl(1), main Freeside documentation in htdocs/docs/

=head1 BUGS

Those modules which would be useful separately should be pulled out, 
renamed appropriately and uploaded to CPAN.  So far: DBIx::DBSchema, Net::SSH
and Net::SCP...

=cut

