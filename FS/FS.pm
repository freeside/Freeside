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

L<FS::Schema> - Freeside database schema

L<FS::Setup> - Setup subroutines

L<FS::Upgrade> - Upgrade subroutines

L<FS::Conf> - Freeside configuration values

L<FS::ConfItem> - Freeside configuration option meta-data.

L<FS::ConfDefaults> - Freeside configuration default and available values

L<FS::UID> - User class (not yet OO)

L<FS::CurrentUser> -  Package representing the current user

L<FS::CGI> - Non OO-subroutines for the web interface.

L<FS::Msgcat> - Message catalog

L<FS::SearchCache> - Search cache

L<FS::AccessRight> - Access control rights.

L<FS::Report> - Report data objects

L<FS::Report::Table> - Report data objects

L<FS::Report::Table::Monthly> - Report data objects

L<FS::XMLRPC> - Backend XML::RPC server

L<FS::Misc> - Miscellaneous subroutines

L<FS::payby> - Payment types

L<FS::ClientAPI_SessionCache> - ClientAPI session cache

L<FS::Pony> - A pony

L<FS::cust_main::Search> - Customer searching

L<FS::cust_main::Import> - Batch customer importing

=head2 Database record classes

L<FS::Record> - Database record base class

L<FS::m2m_Common> - Mixin class for classes in a many-to-many relationship

L<FS::m2name_Common> - Base class for tables with a related table listing names

L<FS::option_Common> - Base class for option sub-classes

L<FS::class_Common> - Base class for classification classes

L<FS::category_Common> - Base class for category (grooups of classifications) classes

L<FS::conf> - Configuration value class

L<FS::payinfo_Mixin>  - Mixin class for records in tables that contain payinfo.

L<FS::access_user> - Employees / internal users

L<FS::access_user_pref> - Employee preferences

L<FS::access_group> - Employee groups

L<FS::access_usergroup> - Employee group membership

L<FS::access_groupagent> - Group reseller access

L<FS::access_right> - Access rights

L<FS::svc_acct_pop> - POP (Point of Presence, not Post
Office Protocol) class

L<FS::part_pop_local> - Local calling area class

L<FS::part_referral> - Referral class

L<FS::pkg_referral> - Package referral class

L<FS::cust_main_county> - Locale (tax rate) class

L<FS::cust_tax_exempt> - Tax exemption record class

L<FS::cust_tax_adjustment> - Tax adjustment record class

L<FS::cust_tax_exempt_pkg> - Line-item specific tax exemption record class

L<FS::svc_Common> - Service base class

L<FS::svc_Parent_Mixin> - Mixin class for svc_ classes with a parent_svcnum field

L<FS::svc_acct> - Account (shell, RADIUS, POP3) class

L<FS::acct_snarf> - External mail account class

L<FS::acct_rt_transaction> - Time worked application to account class

L<FS::radius_usergroup> - RADIUS groups

L<FS::svc_domain> - Domain class

L<FS::domain_record> - DNS zone entries

L<FS::registrar> - Domain registrar class

L<FS::cgp_rule> - Communigate pro rule class

L<FS::cgp_rule_condition> - Communigate pro rule condition class

L<FS::cgp_rule_action> - Communigate pro rule action class

L<FS::svc_forward> - Mail forwarding class

L<FS::svc_mailinglist> - (Customer) Mailing list class

L<FS::mailinglist> - Mailing list class

L<FS::mailinglistmember> - Mailing list member class

L<FS::svc_www> - Web virtual host class.

L<FS::svc_broadband> - DSL, wireless and other broadband class.

L<FS::svc_dsl> - DSL

L<FS::dsl_note> - DSL order notes

L<FS::addr_block> - Address block class

L<FS::router> - Router class

L<FS::part_virtual_field> - Broadband virtual field class

L<FS::svc_phone> - Phone service class

L<FS::phone_device> - Phone device class

L<FS::part_device> - Device definition class

L<FS::phone_avail> - Phone number availability cache

L<FS::cdr> - Call Detail Record class

L<FS::cdr_batch> - Call Detail Record batch class

L<FS::cdr_calltype> - CDR calltype class

L<FS::cdr_carrier> - CDR carrier class

L<FS::cdr_type> - CDR type class

L<FS::svc_external> - Externally tracked service class.

L<FS::svc_pbx> - PBX service class

L<FS::svc_cert> - Certificate service class

L<FS::inventory_class> - Inventory classes

L<FS::inventory_item> - Inventory items

L<FS::part_svc> - Service definition class

L<FS::part_svc_column> - Column constraint class

L<FS::export_svc> - Class linking service definitions (see L<FS::part_svc>)
with exports (see L<FS::part_export>)

L<FS::part_export> - External provisioning export class

L<FS::part_export_option> - Export option class

L<FS::pkg_category> - Package category class (invoice oriented)

L<FS::pkg_class> - Package class class

L<FS::part_pkg> - Package definition class

L<FS::part_pkg_link> - Package definition link class

L<FS::part_pkg_taxclass> - Tax class class

L<FS::part_pkg_option> - Package definition option class

L<FS::part_pkg_report_option> - Package reporting classification class

L<FS::part_pkg_vendor> - Package external mapping class

L<FS::pkg_svc> - Class linking package definitions (see L<FS::part_pkg>) with
service definitions (see L<FS::part_svc>)

L<FS::qual> - Service qualification class

L<FS::qual_option> - Qualification option class

L<FS::reg_code> - One-time registration codes

L<FS::reg_code_pkg> - Class linking registration codes (see L<FS::reg_code>) with package definitions (see L<FS::part_pkg>)

L<FS::rate> - Rate plans for call billing

L<FS::rate_region> - Rate regions for call billing

L<FS::rate_prefix> - Rate region prefixes for call billing

L<FS::rate_detail> - Rate plan detail for call billing

L<FS::usage_class> - Usage class class

L<FS::agent> - Agent (reseller) class

L<FS::agent_type> - Agent type class

L<FS::type_pkgs> - Class linking agent types (see L<FS::agent_type>) with package definitions (see L<FS::part_pkg>)

L<FS::payment_gateway> - Payment gateway class

L<FS::payment_gateway_option> - Payment gateway option class

L<FS::agent_payment_gateway> - Agent payment gateway class

L<FS::cust_svc> - Service class

L<FS::cust_pkg> - Customer package class

L<FS::cust_pkg_option> - Customer package option class

L<FS::cust_pkg_detail> - Customer package details class

L<FS:;cust_pkg_discount> - Customer package discount class

L<FS:;cust_bill_pkg_discount> - Customer package discount line item application class

L<FS:;discount> - Discount class

L<FS::reason_type> - Reason type class

L<FS::reason> - Reason class

L<FS::cust_pkg_reason> - Package reason class

L<FS::contact> - Contact class

L<FS::contact_phone> - Contact phone class

L<FS::phone_type> - Phone type class

L<FS::contact_email> - Contact email class

L<FS::prospect_main> - Prospect class

L<FS::cust_main> - Customer class

L<FS::cust_main::Billing> - Customer billing class

L<FS::cust_main::Billing_Realtime> - Customer real-time billing class

L<FS::cust_main::Packages> - Customer packages class

L<FS::cust_location> - Customer location class

L<FS::cust_main_Mixin> - Mixin class for records that contain fields from cust_main

L<FS::cust_main_invoice> - Invoice destination class

L<FS::cust_class> - Customer classification class

L<FS::cust_category> - Customer category class

L<FS::cust_tag> - Customer tag class

L<FS::part_tag> - Tag definition class

L<FS::cust_main_exemption> - Customer tax exemption class

L<FS::cust_main_note> - Customer note class

L<FS::cust_note_class> - Customer note classification class

L<FS::banned_pay> - Banned payment information class

L<FS::cust_bill> - Invoice class

L<FS::cust_statement> - Informational statement class

L<FS::cust_bill_pkg> - Invoice line item class

L<FS::cust_bill_pkg_detail> - Invoice line item detail class

L<FS::part_bill_event> - (Old) Invoice event definition class

L<FS::cust_bill_event> - (Old) Completed invoice event class

L<FS::part_event> - (New) Billing event definition class

L<FS::part_event_option> - (New) Billing event option class

L<FS::part_event::Condition> - (New) Billing event condition base class

L<FS::part_event::Action> - (New) Billing event action base class

L<FS::part_event_condition> - (New) Billing event condition class

L<FS::part_event_condition_option> - (New) Billing event condition option class

L<FS::part_event_condition_option_option> - (New) Billing event condition compound option class

L<FS::cust_event> - (New) Customer event class

L<FS::cust_bill_ApplicationCommon> - Base class for bill application classes

L<FS::cust_pay> - Payment class

L<FS::cust_pay_pending> - Pending payment class

L<FS::cust_pay_void> - Voided payment class

L<FS::cust_bill_pay> - Payment application class

L<FS::cust_bill_pay_pkg> - Line-item specific payment application class

L<FS::cust_bill_pay_batch> - Batch payment application class

L<FS::cust_credit> - Credit class

L<FS::cust_refund> - Refund class

L<FS::cust_credit_refund> - Refund application to credit class

L<FS::cust_credit_bill> - Credit application to invoice class

L<FS::cust_credit_bill_pkg> - Line-item specific credit application to invoice class

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

L<FS::msg_template> - Message templates (customer notices)

L<FS::msgcat> - Message catalogs (error messages)

L<FS::clientapi_session>

L<FS::clientapi_session_field>

=head2 Historical database record classes

L<FS::h_Common> - History table base class

L<FS::h_cust_pay> - Historical record of customer payment changes

L<FS::h_cust_credit> - Historical record of customer credit changes

L<FS::h_cust_bill> - Historical record of customer tax changes (old-style)

L<FS::h_cust_svc> - Object method for h_cust_svc objects

L<FS::h_cust_tax_exempt> - Historical record of customer tax changes (old-style)

L<FS::h_domain_record> - Historical DNS entry objects

L<FS::h_svc_acct> - Historical account objects

L<FS::h_svc_broadband> - Historical broadband connection objects

L<FS::h_svc_domain> - Historical domain objects

L<FS::h_svc_external> - Historical externally tracked service objects

L<FS::h_svc_forward> - Historical mail forwarding alias objects

L<FS::h_svc_mailinglist> - Historical mailing list objects

L<FS::h_svc_phone> - Historical phone number objects

L<FS::h_svc_pbx> - Historical PBX objects

L<FS::h_svc_www> - Historical web virtual host objects

=head2 Remote API modules

L<FS::SelfService> - Self-service API

L<FS::SelfService::XMLRPC> - Self-service XML-RPC API

=head2 User Interface classes

L<FS::UI::Web> - Web user-interface class

L<FS::UI::bytecount> - Byte counter user-interface class

=head2 Command-line utilities

L<freeside-adduser> - Command line interface to add (freeside) users.

L<freeside-daily> - Run daily billing and collection events.

L<freeside-monthly> - Run monthly billing and invoice collection events.

L<freeside-dbdef-create> - Recreate database schema cache

L<freeside-deluser> - Command line interface to delete (freeside) users.

L<freeside-expiration-alerter> - Emails notifications of credit card expirations.

L<freeside-email> -  Prints email addresses of all users on STDOUT

L<freeside-fetch> - Send a freeside page to a list of employees.

L<freeside-prepaidd> - Real-time daemon for prepaid packages

L<freeside-prune-applications> - Removes stray applications of credit, payment to bills, refunds, etc.

L<freeside-queued> - Job queue daemon

L<freeside-radgroup> - Command line utility to manipulate radius groups

L<freeside-reexport> - Command line tool to re-trigger export jobs for existing services

L<freeside-reset-fixed> - Command line tool to set the fixed columns for existing services

L<freeside-sqlradius-dedup-group> - Command line tool to eliminate duplicate usergroup entries from radius tables

L<freeside-sqlradius-radacctd> - Real-time radacct import daemon

L<freeside-sqlradius-reset> - Command line interface to reset and recreate RADIUS SQL tables

L<freeside-sqlradius-seconds> - Command line time-online tool

L<freeside-upgrade> - Upgrades database schema for new freeside verisons.

=head1 Notes

To quote perl(1), "If you're intending to read these straight through for the
first time, the suggested order will tend to reduce the number of forward
references."

If you've never used OO modules before,
http://www.perl.com/doc/FMTEYEWTK/easy_objects.html might help you out.

=head1 DESCRIPTION

Freeside is a billing and administration package for wired and wireless ISPs,
VoIP, hosting, service and content providers and other online businesses.

The Freeside home page is at <http://www.sisd.com/freeside>.

The main documentation is at <http://www.sisd.com/mediawiki>.

=head1 SUPPORT

A mailing list for users is available.  Send a blank message to
<freeside-users-subscribe@sisd.com> to subscribe.

A mailing list for developers is available.  It is intended to be lower volume
and higher SNR than the users list.  Send a blank message to
<freeside-devel-subscribe@sisd.com> to subscribe.

Commercial support is available; see
<http://www.sisd.com/freeside/commercial.html>.

=head1 AUTHORS

Primarily Ivan Kohler, with help from many kind folks, including core
contributors Jeff Finucane, Kristian Hoffman, Jason Hall and Peter Bowen.

See the CREDITS file in the Freeside distribution for a (hopefully) complete
list and the individal files for details.

=head1 SEE ALSO

perl(1), main Freeside documentation at <http://www.sisd.com/mediawiki/>

=head1 BUGS

Those modules which would be useful separately should be pulled out, 
renamed appropriately and uploaded to CPAN.  So far: DBIx::DBSchema, Net::SSH
and Net::SCP...

=cut

