package FS::SelfService;

use strict;
use vars qw( $VERSION @ISA @EXPORT_OK $DEBUG
             $skip_uid_check $dir $socket %autoload $tag );
use Exporter;
use Socket;
use FileHandle;
#use IO::Handle;
use IO::Select;
use Storable 2.09 qw(nstore_fd fd_retrieve);

$VERSION = '0.03';

@ISA = qw( Exporter );

$DEBUG = 0;

$dir = "/usr/local/freeside";
$socket =  "$dir/selfservice_socket";
$socket .= '.'.$tag if defined $tag && length($tag);

#maybe should ask ClientAPI for this list
%autoload = (
  'passwd'                    => 'passwd/passwd',
  'chfn'                      => 'passwd/passwd',
  'chsh'                      => 'passwd/passwd',
  'login_info'                => 'MyAccount/login_info',
  'login_banner_image'        => 'MyAccount/login_banner_image',
  'login'                     => 'MyAccount/login',
  'logout'                    => 'MyAccount/logout',
  'switch_acct'               => 'MyAccount/switch_acct',
  'customer_info'             => 'MyAccount/customer_info',
  'customer_info_short'       => 'MyAccount/customer_info_short',
  'billing_history'           => 'MyAccount/billing_history',
  'edit_info'                 => 'MyAccount/edit_info',     #add to ss cgi!
  'invoice'                   => 'MyAccount/invoice',
  'invoice_pdf'               => 'MyAccount/invoice_pdf',
  'legacy_invoice'            => 'MyAccount/legacy_invoice',
  'legacy_invoice_pdf'        => 'MyAccount/legacy_invoice_pdf',
  'invoice_logo'              => 'MyAccount/invoice_logo',
  'list_invoices'             => 'MyAccount/list_invoices', #?
  'cancel'                    => 'MyAccount/cancel',        #add to ss cgi!
  'payment_info'              => 'MyAccount/payment_info',
  'payment_info_renew_info'   => 'MyAccount/payment_info_renew_info',
  'process_payment'           => 'MyAccount/process_payment',
  'store_payment'             => 'MyAccount/store_payment',
  'process_stored_payment'    => 'MyAccount/process_stored_payment',
  'process_payment_order_pkg' => 'MyAccount/process_payment_order_pkg',
  'process_payment_change_pkg' => 'MyAccount/process_payment_change_pkg',
  'process_payment_order_renew' => 'MyAccount/process_payment_order_renew',
  'process_prepay'            => 'MyAccount/process_prepay',
  'realtime_collect'          => 'MyAccount/realtime_collect',
  'list_pkgs'                 => 'MyAccount/list_pkgs',     #add to ss (added?)
  'list_svcs'                 => 'MyAccount/list_svcs',     #add to ss (added?)
  'list_svc_usage'            => 'MyAccount/list_svc_usage',   
  'svc_status_html'           => 'MyAccount/svc_status_html',
  'svc_status_hash'           => 'MyAccount/svc_status_hash',
  'set_svc_status_hash'       => 'MyAccount/set_svc_status_hash',
  'set_svc_status_listadd'    => 'MyAccount/set_svc_status_listadd',
  'set_svc_status_listdel'    => 'MyAccount/set_svc_status_listdel',
  'set_svc_status_vacationadd'=> 'MyAccount/set_svc_status_vacationadd',
  'set_svc_status_vacationdel'=> 'MyAccount/set_svc_status_vacationdel',
  'acct_forward_info'         => 'MyAccount/acct_forward_info',
  'process_acct_forward'      => 'MyAccount/process_acct_forward',
  'list_dsl_devices'          => 'MyAccount/list_dsl_devices',   
  'add_dsl_device'            => 'MyAccount/add_dsl_device',   
  'delete_dsl_device'         => 'MyAccount/delete_dsl_device',   
  'port_graph'                => 'MyAccount/port_graph',   
  'list_cdr_usage'            => 'MyAccount/list_cdr_usage',   
  'list_support_usage'        => 'MyAccount/list_support_usage',   
  'order_pkg'                 => 'MyAccount/order_pkg',     #add to ss cgi!
  'change_pkg'                => 'MyAccount/change_pkg', 
  'order_recharge'            => 'MyAccount/order_recharge',
  'renew_info'                => 'MyAccount/renew_info',
  'order_renew'               => 'MyAccount/order_renew',
  'cancel_pkg'                => 'MyAccount/cancel_pkg',    #add to ss cgi!
  'suspend_pkg'               => 'MyAccount/suspend_pkg',   #add to ss cgi!
  'charge'                    => 'MyAccount/charge',        #?
  'part_svc_info'             => 'MyAccount/part_svc_info',
  'provision_acct'            => 'MyAccount/provision_acct',
  'provision_phone'           => 'MyAccount/provision_phone',
  'provision_external'        => 'MyAccount/provision_external',
  'unprovision_svc'           => 'MyAccount/unprovision_svc',
  'myaccount_passwd'          => 'MyAccount/myaccount_passwd',
  'reset_passwd'              => 'MyAccount/reset_passwd',
  'check_reset_passwd'        => 'MyAccount/check_reset_passwd',
  'process_reset_passwd'      => 'MyAccount/process_reset_passwd',
  'list_tickets'              => 'MyAccount/list_tickets',
  'create_ticket'             => 'MyAccount/create_ticket',
  'get_ticket'                => 'MyAccount/get_ticket',
  'adjust_ticket_priority'    => 'MyAccount/adjust_ticket_priority',
  'did_report'                => 'MyAccount/did_report',
  'signup_info'               => 'Signup/signup_info',
  'skin_info'                 => 'MyAccount/skin_info',
  'access_info'               => 'MyAccount/access_info',
  'domain_select_hash'        => 'Signup/domain_select_hash',  # expose?
  'new_customer'              => 'Signup/new_customer',
  'new_customer_minimal'      => 'Signup/new_customer_minimal',
  'capture_payment'           => 'Signup/capture_payment',
  #N/A 'clear_signup_cache'        => 'Signup/clear_cache',
  'new_agent'                 => 'Agent/new_agent',
  'agent_login'               => 'Agent/agent_login',
  'agent_logout'              => 'Agent/agent_logout',
  'agent_info'                => 'Agent/agent_info',
  'agent_list_customers'      => 'Agent/agent_list_customers',
  'check_username'            => 'Agent/check_username',
  'suspend_username'          => 'Agent/suspend_username',
  'unsuspend_username'        => 'Agent/unsuspend_username',
  'mason_comp'                => 'MasonComponent/mason_comp',
  'call_time'                 => 'PrepaidPhone/call_time',
  'call_time_nanpa'           => 'PrepaidPhone/call_time_nanpa',
  'phonenum_balance'          => 'PrepaidPhone/phonenum_balance',

  'start_thirdparty'          => 'MyAccount/start_thirdparty',
  'finish_thirdparty'         => 'MyAccount/finish_thirdparty',

  'list_quotations'           => 'MyAccount/quotation/list_quotations',
  'quotation_new'             => 'MyAccount/quotation/quotation_new',
  'quotation_delete'          => 'MyAccount/quotation/quotation_delete',
  'quotation_info'            => 'MyAccount/quotation/quotation_info',
  'quotation_print'           => 'MyAccount/quotation/quotation_print',
  'quotation_add_pkg'         => 'MyAccount/quotation/quotation_add_pkg',
  'quotation_remove_pkg'      => 'MyAccount/quotation/quotation_remove_pkg',
  'quotation_order'           => 'MyAccount/quotation/quotation_order',

);
@EXPORT_OK = (
  keys(%autoload),
  qw( regionselector regionselector_hashref location_form
      expselect popselector domainselector didselector
    )
);

$ENV{'PATH'} ='/usr/bin:/usr/ucb:/bin';
$ENV{'SHELL'} = '/bin/sh';
$ENV{'IFS'} = " \t\n";
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'} = '';

#you can add BEGIN { $FS::SelfService::skip_uid_check = 1; } 
#if you grant appropriate permissions to whatever user
my $freeside_uid = scalar(getpwnam('freeside'));
die "not running as the freeside user\n"
  if $> != $freeside_uid && ! $skip_uid_check;

-e $dir or die "FATAL: $dir doesn't exist!";
-d $dir or die "FATAL: $dir isn't a directory!";
-r $dir or die "FATAL: Can't read $dir as freeside user!";
-x $dir or die "FATAL: $dir not searchable (executable) as freeside user!";

foreach my $autoload ( keys %autoload ) {

  my $eval =
  "sub $autoload { ". '
                   my $param;
                   if ( ref($_[0]) ) {
                     $param = shift;
                   } else {
                     #warn scalar(@_). ": ". join(" / ", @_);
                     $param = { @_ };
                   }

                   $param->{_packet} = \''. $autoload{$autoload}. '\';

                   simple_packet($param);
                 }';

  eval $eval;
  die $@ if $@;

}

sub simple_packet {
  my $packet = shift;
  warn "sending ". $packet->{_packet}. " to server"
    if $DEBUG;
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($socket)) or die "connect to $socket: $!";
  nstore_fd($packet, \*SOCK) or die "can't send packet: $!";
  SOCK->flush;

  #shoudl trap: Magic number checking on storable file failed at blib/lib/Storable.pm (autosplit into blib/lib/auto/Storable/fd_retrieve.al) line 337, at /usr/local/share/perl/5.6.1/FS/SelfService.pm line 71

  #block until there is a message on socket
#  my $w = new IO::Select;
#  $w->add(\*SOCK);
#  my @wait = $w->can_read;

  warn "reading message from server"
    if $DEBUG;

  my $return = fd_retrieve(\*SOCK) or die "error reading result: $!";
  die $return->{'_error'} if defined $return->{_error} && $return->{_error};

  warn "returning message to client"
    if $DEBUG;

  $return;
}

=head1 NAME

FS::SelfService - Freeside self-service API

=head1 SYNOPSIS

  # password and shell account changes
  use FS::SelfService qw(passwd chfn chsh);

  # "my account" functionality
  use FS::SelfService qw( login customer_info invoice cancel payment_info process_payment );

  #new-style login with an email address and password
  # can also be used for svc_acct login, set $emailaddress to username@domain
  my $rv = login ( { 'email'    => $emailaddress,
                     'password' => $password,
                   },
                 );
  if ( $rv->{'error'} ) {
    #handle login error...
  } else {
    #successful login
    $session_id = $rv->{'session_id'};
  }

  #classic svc_acct-based login with separate username and password
  my $rv = login( { 'username' => $username,
                    'domain'   => $domain,
                    'password' => $password,
                  }
                );
  if ( $rv->{'error'} ) {
    #handle login error...
  } else {
    #successful login
    $session_id = $rv->{'session_id'};
  }

  #svc_phone login with phone number and PIN
  my $rv = login( { 'username' => $phone_number,
                    'domain'   => 'svc_phone',
                    'password' => $pin,
                  }
                );
  if ( $rv->{'error'} ) {
    #handle login error...
  } else {
    #successful login
    $session_id = $rv->{'session_id'};
  }

  my $customer_info = customer_info( { 'session_id' => $session_id } );

  #payment_info and process_payment are available in 1.5+ only
  my $payment_info = payment_info( { 'session_id' => $session_id } );

  #!!! process_payment example

  #!!! list_pkgs example

  #!!! order_pkg example

  #quoting a package, then ordering after confirmation

  my $rv = quotation_new({ 'session_id' => $session_id });
  my $qnum = $rv->{quotationnum};
  #  add packages to the quotation
  $rv = quotation_add_pkg({ 'session_id'   => $session_id,
                            'quotationnum' => $qnum,
                            'pkgpart'      => $pkgpart,
                            'quantity'     => $quantity, # defaults to 1
                          });
  #  repeat until all packages are added
  #  view the pricing information
  $rv = quotation_info({ 'session_id'   => $session_id,
                         'quotationnum' => $qnum,
                      });
  print "Total setup charges: ".$rv->{total_setup}."\n".
        "Total recurring charges: ".$rv->{total_recur}."\n";
  #  quotation_info also provides a detailed breakdown of charges, in
  #  $rv->{sections}.

  #  ask customer for confirmation, then:
  $rv = quotation_order({ 'session_id'   => $session_id,
                          'quotationnum' => $qnum,
                        });

  #!!! cancel_pkg example

  # signup functionality
  use FS::SelfService qw( signup_info new_customer new_customer_minimal );

  my $signup_info = signup_info;

  $rv = new_customer( {
                        'first'            => $first,
                        'last'             => $last,
                        'company'          => $company,
                        'address1'         => $address1,
                        'address2'         => $address2,
                        'city'             => $city,
                        'state'            => $state,
                        'zip'              => $zip,
                        'country'          => $country,
                        'daytime'          => $daytime,
                        'night'            => $night,
                        'fax'              => $fax,
                        'payby'            => $payby,
                        'payinfo'          => $payinfo,
                        'paycvv'           => $paycvv,
                        'paystart_month'   => $paystart_month
                        'paystart_year'    => $paystart_year,
                        'payissue'         => $payissue,
                        'payip'            => $payip
                        'paydate'          => $paydate,
                        'payname'          => $payname,
                        'invoicing_list'   => $invoicing_list,
                        'referral_custnum' => $referral_custnum,
                        'agentnum'         => $agentnum,
                        'pkgpart'          => $pkgpart,

                        'username'         => $username,
                        '_password'        => $password,
                        'popnum'           => $popnum,
                        #OR
                        'countrycode'      => 1,
                        'phonenum'         => $phonenum,
                        'pin'              => $pin,
                      }
                    );
  
  my $error = $rv->{'error'};
  if ( $error eq '_decline' ) {
    print_decline();
  } elsif ( $error ) {
    reprint_signup();
  } else {
    print_success();
  }

=head1 DESCRIPTION

Use this API to implement your own client "self-service" module.

If you just want to customize the look of the existing "self-service" module,
see XXXX instead.

=head1 PASSWORD, GECOS, SHELL CHANGING FUNCTIONS

=over 4

=item passwd

Changes the password for an existing user in svc_acct.  Takes a hash
reference with the following keys:

=over 4

=item username

Username of the account (required)

=item domain

Domain of the account (required)

=item old_password

Old password (required)

=item new_password
 
New password (required)

=item new_gecos

New gecos

=item new_shell

New Shell

=back 

=item chfn

=item chsh

=back

=head1 "MY ACCOUNT" FUNCTIONS

=over 4

=item login HASHREF

Creates a user session.  Takes a hash reference as parameter with the
following keys:

=over 4

=item email

Email address (username@domain), instead of username and domain.  Required for
contact-based self-service login, can also be used for svc_acct-based login.

=item username

Username

=item domain

Domain

=item password

Password

=back

Returns a hash reference with the following keys:

=over 4

=item error

Empty on success, or an error message on errors.

=item session_id

Session identifier for successful logins

=back

=item customer_info HASHREF

Returns general customer information.

Takes a hash reference as parameter with a single key: B<session_id>

Returns a hash reference with the following keys:

=over 4

=item name

Customer name

=item balance

Balance owed

=item open

Array reference of hash references of open inoices.  Each hash reference has
the following keys: invnum, date, owed

=item small_custview

An HTML fragment containing shipping and billing addresses.

=item The following fields are also returned

first last company address1 address2 city county state zip country daytime night fax ship_first ship_last ship_company ship_address1 ship_address2 ship_city ship_state ship_zip ship_country ship_daytime ship_night ship_fax payby payinfo payname month year invoicing_list postal_invoicing

=back

=item edit_info HASHREF

Takes a hash reference as parameter with any of the following keys:

first last company address1 address2 city county state zip country daytime night fax ship_first ship_last ship_company ship_address1 ship_address2 ship_city ship_state ship_zip ship_country ship_daytime ship_night ship_fax payby payinfo paycvv payname month year invoicing_list postal_invoicing

If a field exists, the customer record is updated with the new value of that
field.  If a field does not exist, that field is not changed on the customer
record.

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors

=item invoice HASHREF

Returns an invoice.  Takes a hash reference as parameter with two keys:
session_id and invnum

Returns a hash reference with the following keys:

=over 4

=item error

Empty on success, or an error message on errors

=item invnum

Invoice number

=item invoice_text

Invoice text

=back

=item list_invoices HASHREF

Returns a list of all customer invoices.  Takes a hash references with a single
key, session_id.

Returns a hash reference with the following keys:

=over 4

=item error

Empty on success, or an error message on errors

=item invoices

Reference to array of hash references with the following keys:

=over 4

=item invnum

Invoice ID

=item _date

Invoice date, in UNIX epoch time

=back

=back

=item cancel HASHREF

Cancels this customer.

Takes a hash reference as parameter with a single key: B<session_id>

Returns a hash reference with a single key, B<error>, which is empty on
success or an error message on errors.

=item payment_info HASHREF

Returns information that may be useful in displaying a payment page.

Takes a hash reference as parameter with a single key: B<session_id>.

Returns a hash reference with the following keys:

=over 4

=item error

Empty on success, or an error message on errors

=item balance

Balance owed

=item payname

Exact name on credit card (CARD/DCRD)

=item address1

Address line one

=item address2

Address line two

=item city

City

=item state

State

=item zip

Zip or postal code

=item payby

Customer's current default payment type.

=item card_type

For CARD/DCRD payment types, the card type (Visa card, MasterCard, Discover card, American Express card, etc.)

=item payinfo

For CARD/DCRD payment types, the card number

=item month

For CARD/DCRD payment types, expiration month

=item year

For CARD/DCRD payment types, expiration year

=item cust_main_county

County/state/country data - array reference of hash references, each of which has the fields of a cust_main_county record (see L<FS::cust_main_county>).  Note these are not FS::cust_main_county objects, but hash references of columns and values.

=item states

Array reference of all states in the current default country.

=item card_types

Hash reference of card types; keys are card types, values are the exact strings
passed to the process_payment function

=cut

#this doesn't actually work yet
#
#=item paybatch
#
#Unique transaction identifier (prevents multiple charges), passed to the
#process_payment function

=back

=item process_payment HASHREF

Processes a payment and possible change of address or payment type.  Takes a
hash reference as parameter with the following keys:

=over 4

=item session_id

Session identifier

=item amount

Amount

=item save

If true, address and card information entered will be saved for subsequent
transactions.

=item auto

If true, future credit card payments will be done automatically (sets payby to
CARD).  If false, future credit card payments will be done on-demand (sets
payby to DCRD).  This option only has meaning if B<save> is set true.  

=item payname

Name on card

=item address1

Address line one

=item address2

Address line two

=item city

City

=item state

State

=item zip

Zip or postal code

=item country

Two-letter country code

=item payinfo

Card number

=item month

Card expiration month

=item year

Card expiration year

=cut

#this doesn't actually work yet
#
#=item paybatch
#
#Unique transaction identifier, returned from the payment_info function.
#Prevents multiple charges.

=back

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors.

=item process_payment_order_pkg

Combines the B<process_payment> and B<order_pkg> functions in one step.  If the
payment processes sucessfully, the package is ordered.  Takes a hash reference
as parameter with the keys of both methods.

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors.

=item process_payment_change_pkg

Combines the B<process_payment> and B<change_pkg> functions in one step.  If the
payment processes sucessfully, the package is ordered.  Takes a hash reference
as parameter with the keys of both methods.

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors.


=item process_payment_order_renew

Combines the B<process_payment> and B<order_renew> functions in one step.  If
the payment processes sucessfully, the renewal is processed.  Takes a hash
reference as parameter with the keys of both methods.

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors.

=item list_pkgs

Returns package information for this customer.  For more detail on services,
see L</list_svcs>.

Takes a hash reference as parameter with a single key: B<session_id>

Returns a hash reference containing customer package information.  The hash reference contains the following keys:

=over 4

=item custnum

Customer number

=item error

Empty on success, or an error message on errors.

=item cust_pkg HASHREF

Array reference of hash references, each of which has the fields of a cust_pkg
record (see L<FS::cust_pkg>) as well as the fields below.  Note these are not
the internal FS:: objects, but hash references of columns and values.

=over 4

=item part_pkg fields

All fields of part_pkg for this specific cust_pkg (be careful with this
information - it may reveal more about your available packages than you would
like users to know in aggregate) 

=cut

#XXX pare part_pkg fields down to a more secure subset

=item part_svc

An array of hash references indicating information on unprovisioned services
available for provisioning for this specific cust_pkg.  Each has the following
keys:

=over 4

=item part_svc fields

All fields of part_svc (be careful with this information - it may reveal more
about your available packages than you would like users to know in aggregate) 

=cut

#XXX pare part_svc fields down to a more secure subset

=back

=item cust_svc

An array of hash references indicating information on the customer services
already provisioned for this specific cust_pkg.  Each has the following keys:

=over 4

=item label

Array reference with three elements: The first element is the name of this service.  The second element is a meaningful user-specific identifier for the service (i.e. username, domain or mail alias).  The last element is the table name of this service.

=back

=item svcnum

Primary key for this service

=item svcpart

Service definition (see L<FS::part_svc>)

=item pkgnum

Customer package (see L<FS::cust_pkg>)

=item overlimit

Blank if the service is not over limit, or the date the service exceeded its usage limit (as a UNIX timestamp).

=back

=back

=item list_svcs

Returns service information for this customer.

Takes a hash reference as parameter with a single key: B<session_id>

Returns a hash reference containing customer package information.  The hash reference contains the following keys:

=over 4

=item custnum

Customer number

=item svcs

An array of hash references indicating information on all of this customer's
services.  Each has the following keys:

=over 4

=item svcnum

Primary key for this service

=item label

Name of this service

=item value

Meaningful user-specific identifier for the service (i.e. username, domain, or
mail alias).

=back

Account (svc_acct) services also have the following keys:

=over 4

=item username

Username

=item email

username@domain

=item seconds

Seconds remaining

=item upbytes

Upload bytes remaining

=item downbytes

Download bytes remaining

=item totalbytes

Total bytes remaining

=item recharge_amount

Cost of a recharge

=item recharge_seconds

Number of seconds gained by recharge

=item recharge_upbytes

Number of upload bytes gained by recharge

=item recharge_downbytes

Number of download bytes gained by recharge

=item recharge_totalbytes

Number of total bytes gained by recharge

=back

=back

=item order_pkg

Orders a package for this customer.

Takes a hash reference as parameter with the following keys:

=over 4

=item session_id

Session identifier

=item pkgpart

Package to order (see L<FS::part_pkg>).

=item quantity

Quantity for this package order (default 1).

=item locationnum

Optional locationnum for this package order, for existing locations.

Or, for new locations, pass the following fields: address1*, address2, city*,
county, state*, zip*, country.  (* = required in this case)

=item address1

=item address 2

=item city

=item 

=item svcpart

Service to order (see L<FS::part_svc>).

Normally optional; required only to provision a non-svc_acct service, or if the
package definition does not contain one svc_acct service definition with
quantity 1 (it may contain others with quantity >1).  A svcpart of "none" can
also be specified to indicate that no initial service should be provisioned.

=back

Fields used when provisioning an svc_acct service:

=over 4

=item username

Username

=item _password

Password

=item sec_phrase

Optional security phrase

=item popnum

Optional Access number number

=back

Fields used when provisioning an svc_domain service:

=over 4

=item domain

Domain

=back

Fields used when provisioning an svc_phone service:

=over 4

=item phonenum

Phone number

=item pin

Voicemail PIN

=item sip_password

SIP password

=back

Fields used when provisioning an svc_external service:

=over 4

=item id

External numeric ID.

=item title

External text title.

=back

Fields used when provisioning an svc_pbx service:

=over 4

=item id

Numeric ID.

=item name

Text name.

=back

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors.  The special error '_decline' is returned for
declined transactions.

=item change_pkg

Changes a package for this customer.

Takes a hash reference as parameter with the following keys:

=over 4

=item session_id

Session identifier

=item pkgnum

Existing customer package.

=item pkgpart

New package to order (see L<FS::part_pkg>).

=item quantity

Quantity for this package order (default 1).

=back

Returns a hash reference with the following keys:

=over 4

=item error

Empty on success, or an error message on errors.  

=item pkgnum

On success, the new pkgnum

=back


=item renew_info

Provides useful info for early renewals.

Takes a hash reference as parameter with the following keys:

=over 4

=item session_id

Session identifier

=back

Returns a hash reference.  On errors, it contains a single key, B<error>, with
the error message.  Otherwise, contains a single key, B<dates>, pointing to
an array refernce of hash references.  Each hash reference contains the
following keys:

=over 4

=item bill_date

(Future) Bill date.  Indicates a future date for which billing could be run.
Specified as a integer UNIX timestamp.  Pass this value to the B<order_renew>
function.

=item bill_date_pretty

(Future) Bill date as a human-readable string.  (Convenience for display;
subject to change, so best not to parse for the date.)

=item amount

Base amount which will be charged if renewed early as of this date.

=item renew_date

Renewal date; i.e. even-futher future date at which the customer will be paid
through if the early renewal is completed with the given B<bill-date>.
Specified as a integer UNIX timestamp.

=item renew_date_pretty

Renewal date as a human-readable string.  (Convenience for display;
subject to change, so best not to parse for the date.)

=item pkgnum

Package that will be renewed.

=item expire_date

Expiration date of the package that will be renewed.

=item expire_date_pretty

Expiration date of the package that will be renewed, as a human-readable
string.  (Convenience for display; subject to change, so best not to parse for
the date.)

=back

=item order_renew

Renews this customer early; i.e. runs billing for this customer in advance.

Takes a hash reference as parameter with the following keys:

=over 4

=item session_id

Session identifier

=item date

Integer date as returned by the B<renew_info> function, indicating the advance
date for which to run billing.

=back

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors.

=item cancel_pkg

Cancels a package for this customer.

Takes a hash reference as parameter with the following keys:

=over 4

=item session_id

Session identifier

=item pkgpart

pkgpart of package to cancel

=back

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors.

=item provision_acct 

Provisions an account (svc_acct).

Takes a hash references as parameter with the following keys:

=over 4

=item session_id

Session identifier

=item pkgnum

pkgnum of package into which this service is provisioned

=item svcpart

svcpart or service definition to provision

=item username

=item domsvc

=item _password

=back

=item provision_phone

Provisions a phone number (svc_phone).

Takes a hash references as parameter with the following keys:

=over 4

=item session_id

Session identifier

=item pkgnum

pkgnum of package into which this service is provisioned

=item svcpart

svcpart or service definition to provision

=item countrycode

=item phonenum

=item address1

=item address2

=item city

=item county

=item state

=item zip

=item country

E911 Address (optional)

=back

=item provision_external

Provisions an external service (svc_external).

Takes a hash references as parameter with the following keys:

=over 4

=item session_id

Session identifier

=item pkgnum

pkgnum of package into which this service is provisioned

=item svcpart

svcpart or service definition to provision

=item id

=item title

=back

=back

=head2 "MY ACCOUNT" QUOTATION FUNCTIONS

All of these functions require the user to be logged in, and the 'session_id'
key to be included in the argument hashref.`

=over 4

=item list_quotations HASHREF

Returns a hashref listing this customer's active self-service quotations.
Contents are:

- 'quotations', an arrayref containing an element for each quotation.
  - quotationnum, the primary key
  - _date, the date it was started
  - num_pkgs, the number of packages
  - total_setup, the sum of setup fees
  - total_recur, the sum of recurring charges

=item quotation_new HASHREF

Creates an empty quotation and returns a hashref containing 'quotationnum',
the primary key of the new quotation.

=item quotation_delete HASHREF

Disables (does not really delete) a quotation. Takes the following arguments:

=over 4

=item session_id

=item quotationnum - the quotation to delete

=back

Returns 'error' => a string, which will be empty on success.

=item quotation_info HASHREF

Returns total and detailed pricing information on a quotation.

Takes the following arguments:

=over 4

=item session_id

=item quotationnum - the quotation to return

=back

Returns a hashref containing:

- total_setup, the total of setup fees (and their taxes)
- total_recur, the total of all recurring charges (and their taxes)
- sections, an arrayref containing an element for each quotation section.
  - description, a line of text describing the group of charges
  - subtotal, the total of charges in this group (if appropriate)
  - detail_items, an arrayref of line items
    - pkgnum, the reference number of the package
    - description, the package name (or tax name)
    - quantity
    - amount, the amount charged
    If the detail item represents a subtotal, it will instead contain:
    - total_item: description of the subtotal
    - total_amount: the subtotal amount


=item quotation_print HASHREF

Renders the quotation as HTML or PDF. Takes the following arguments:

=over 4

=item session_id

=item quotationnum - the quotation to return

=item format - 'html' or 'pdf'

=back

Returns a hashref containing 'document', the contents of the file.

=item quotation_add_pkg HASHREF

Adds a package to a quotation. Takes the following arguments:

=over 4

=item session_id

=item pkgpart - the package to add

=item quotationnum - the quotation to add it to

=item quantity - the package quantity (defaults to 1)

=item address1, address2, city, state, zip, country - address fields to set
the service location

=back

Returns 'error' => a string, which will be empty on success.

=item quotation_remove_pkg HASHREF

Removes a package from a quotation. Takes the following arguments:

=over 4

=item session_id

=item pkgnum - the primary key (quotationpkgnum) of the package to remove

=item quotationnum - the quotation to remove it from

=back

Returns 'error' => a string, which will be empty on success.

=back

=item quotation_order HASHREF

Converts the packages in a quotation into real packages. Takes the following
arguments:

Takes the following arguments:

=over 4

=item session_id

=item quotationnum - the quotation to order

=back

=back

=head1 SIGNUP FUNCTIONS

=over 4

=item signup_info HASHREF

Takes a hash reference as parameter with the following keys:

=over 4

=item session_id - Optional agent/reseller interface session

=back

Returns a hash reference containing information that may be useful in
displaying a signup page.  The hash reference contains the following keys:

=over 4

=item cust_main_county

County/state/country data - array reference of hash references, each of which has the fields of a cust_main_county record (see L<FS::cust_main_county>).  Note these are not FS::cust_main_county objects, but hash references of columns and values.

=item part_pkg

Available packages - array reference of hash references, each of which has the fields of a part_pkg record (see L<FS::part_pkg>).  Each hash reference also has an additional 'payby' field containing an array reference of acceptable payment types specific to this package (see below and L<FS::part_pkg/payby>).  Note these are not FS::part_pkg objects, but hash references of columns and values.  Requires the 'signup_server-default_agentnum' configuration value to be set, or
an agentnum specified explicitly via reseller interface session_id in the
options.

=item agent

Array reference of hash references, each of which has the fields of an agent record (see L<FS::agent>).  Note these are not FS::agent objects, but hash references of columns and values.

=item agentnum2part_pkg

Hash reference; keys are agentnums, values are array references of available packages for that agent, in the same format as the part_pkg arrayref above.

=item svc_acct_pop

Access numbers - array reference of hash references, each of which has the fields of an svc_acct_pop record (see L<FS::svc_acct_pop>).  Note these are not FS::svc_acct_pop objects, but hash references of columns and values.

=item security_phrase

True if the "security_phrase" feature is enabled

=item payby

Array reference of acceptable payment types for signup

=over 4

=item CARD

credit card - automatic

=item DCRD

credit card - on-demand - version 1.5+ only

=item CHEK

electronic check - automatic

=item DCHK

electronic check - on-demand - version 1.5+ only

=item LECB

Phone bill billing

=item BILL

billing, not recommended for signups

=item COMP

free, definitely not recommended for signups

=item PREPAY

special billing type: applies a credit (see FS::prepay_credit) and sets billing type to BILL

=back

=item cvv_enabled

True if CVV features are available (1.5+ or 1.4.2 with CVV schema patch)

=item msgcat

Hash reference of message catalog values, to support error message customization.  Currently available keys are: passwords_dont_match, invalid_card, unknown_card_type, and not_a (as in "Not a Discover card").  Values are configured in the web interface under "View/Edit message catalog".

=item statedefault

Default state

=item countrydefault

Default country

=back

=item new_customer_minimal HASHREF

Creates a new customer.

Current differences from new_customer: An address is not required.  promo_code
and reg_code are not supported.  If invoicing_list and _password is passed, a
contact will be created with self-service access (no pkgpart or username is
necessary).  No initial billing is run (this may change in a future version).

Takes a hash reference as parameter with the following keys:

=over 4

=item first

first name (required)

=item last

last name (required)

=item ss

(not typically collected; mostly used for ACH transactions)

=item company

Company name

=item address1

Address line one

=item address2

Address line two

=item city

City

=item county

County

=item state

State

=item zip

Zip or postal code

=item daytime

Daytime phone number

=item night

Evening phone number

=item fax

Fax number

=item payby

CARD, DCRD, CHEK, DCHK, LECB, BILL, COMP or PREPAY (see L</signup_info> (required)

=item payinfo

Card number for CARD/DCRD, account_number@aba_number for CHEK/DCHK, prepaid "pin" for PREPAY, purchase order number for BILL

=item paycvv

Credit card CVV2 number (1.5+ or 1.4.2 with CVV schema patch)

=item paydate

Expiration date for CARD/DCRD

=item payname

Exact name on credit card for CARD/DCRD, bank name for CHEK/DCHK

=item invoicing_list

comma-separated list of email addresses for email invoices.  The special value 'POST' is used to designate postal invoicing (it may be specified alone or in addition to email addresses),

=item referral_custnum

referring customer number

=item agentnum

Agent number

=item pkgpart

pkgpart of initial package

=item username

Username

=item _password

Password

=item sec_phrase

Security phrase

=item popnum

Access number (index, not the literal number)

=item countrycode

Country code (to be provisioned as a service)

=item phonenum

Phone number (to be provisioned as a service)

=item pin

Voicemail PIN

=back

Returns a hash reference with the following keys:

=over 4

=item error

Empty on success, or an error message on errors.  The special error '_decline' is returned for declined transactions; other error messages should be suitable for display to the user (and are customizable in under Configuration | View/Edit message catalog)

=back

=item new_customer HASHREF

Creates a new customer.  Takes a hash reference as parameter with the
following keys:

=over 4

=item first

first name (required)

=item last

last name (required)

=item ss

(not typically collected; mostly used for ACH transactions)

=item company

Company name

=item address1 (required)

Address line one

=item address2

Address line two

=item city (required)

City

=item county

County

=item state (required)

State

=item zip (required)

Zip or postal code

=item daytime

Daytime phone number

=item night

Evening phone number

=item fax

Fax number

=item payby

CARD, DCRD, CHEK, DCHK, LECB, BILL, COMP or PREPAY (see L</signup_info> (required)

=item payinfo

Card number for CARD/DCRD, account_number@aba_number for CHEK/DCHK, prepaid "pin" for PREPAY, purchase order number for BILL

=item paycvv

Credit card CVV2 number (1.5+ or 1.4.2 with CVV schema patch)

=item paydate

Expiration date for CARD/DCRD

=item payname

Exact name on credit card for CARD/DCRD, bank name for CHEK/DCHK

=item invoicing_list

comma-separated list of email addresses for email invoices.  The special value 'POST' is used to designate postal invoicing (it may be specified alone or in addition to email addresses),

=item referral_custnum

referring customer number

=item agentnum

Agent number

=item pkgpart

pkgpart of initial package

=item username

Username

=item _password

Password

=item sec_phrase

Security phrase

=item popnum

Access number (index, not the literal number)

=item countrycode

Country code (to be provisioned as a service)

=item phonenum

Phone number (to be provisioned as a service)

=item pin

Voicemail PIN

=back

Returns a hash reference with the following keys:

=over 4

=item error

Empty on success, or an error message on errors.  The special error '_decline' is returned for declined transactions; other error messages should be suitable for display to the user (and are customizable in under Configuration | View/Edit message catalog)

=back

=item regionselector HASHREF | LIST

Takes as input a hashref or list of key/value pairs with the following keys:

=over 4

=item selected_county

Currently selected county

=item selected_state

Currently selected state

=item selected_country

Currently selected country

=item prefix

Specify a unique prefix string  if you intend to use the HTML output multiple time son one page.

=item onchange

Specify a javascript subroutine to call on changes

=item default_state

Default state

=item default_country

Default country

=item locales

An arrayref of hash references specifying regions.  Normally you can just pass the value of the I<cust_main_county> field returned by B<signup_info>.

=back

Returns a list consisting of three HTML fragments for county selection,
state selection and country selection, respectively.

=cut

#false laziness w/FS::cust_main_county (this is currently the "newest" version)
sub regionselector {
  my $param;
  if ( ref($_[0]) ) {
    $param = shift;
  } else {
    $param = { @_ };
  }
  $param->{'selected_country'} ||= $param->{'default_country'};
  $param->{'selected_state'} ||= $param->{'default_state'};

  my $prefix = exists($param->{'prefix'}) ? $param->{'prefix'} : '';

  my $countyflag = 0;

  my %cust_main_county;

#  unless ( @cust_main_county ) { #cache 
    #@cust_main_county = qsearch('cust_main_county', {} );
    #foreach my $c ( @cust_main_county ) {
    foreach my $c ( @{ $param->{'locales'} } ) {
      #$countyflag=1 if $c->county;
      $countyflag=1 if $c->{county};
      #push @{$cust_main_county{$c->country}{$c->state}}, $c->county;
      #$cust_main_county{$c->country}{$c->state}{$c->county} = 1;
      $cust_main_county{$c->{country}}{$c->{state}}{$c->{county}} = 1;
    }
#  }
  $countyflag=1 if $param->{selected_county};

  my $script_html = <<END;
    <SCRIPT>
    function opt(what,value,text) {
      var optionName = new Option(text, value, false, false);
      var length = what.length;
      what.options[length] = optionName;
    }
    function ${prefix}country_changed(what) {
      country = what.options[what.selectedIndex].text;
      for ( var i = what.form.${prefix}state.length; i >= 0; i-- )
          what.form.${prefix}state.options[i] = null;
END
      #what.form.${prefix}state.options[0] = new Option('', '', false, true);

  foreach my $country ( sort keys %cust_main_county ) {
    $script_html .= "\nif ( country == \"$country\" ) {\n";
    foreach my $state ( sort keys %{$cust_main_county{$country}} ) {
      my $text = $state || '(n/a)';
      $script_html .= qq!opt(what.form.${prefix}state, "$state", "$text");\n!;
    }
    $script_html .= "}\n";
  }

  $script_html .= <<END;
    }
    function ${prefix}state_changed(what) {
END

  if ( $countyflag ) {
    $script_html .= <<END;
      state = what.options[what.selectedIndex].text;
      country = what.form.${prefix}country.options[what.form.${prefix}country.selectedIndex].text;
      for ( var i = what.form.${prefix}county.length; i >= 0; i-- )
          what.form.${prefix}county.options[i] = null;
END

    foreach my $country ( sort keys %cust_main_county ) {
      $script_html .= "\nif ( country == \"$country\" ) {\n";
      foreach my $state ( sort keys %{$cust_main_county{$country}} ) {
        $script_html .= "\nif ( state == \"$state\" ) {\n";
          #foreach my $county ( sort @{$cust_main_county{$country}{$state}} ) {
          foreach my $county ( sort keys %{$cust_main_county{$country}{$state}} ) {
            my $text = $county || '(n/a)';
            $script_html .=
              qq!opt(what.form.${prefix}county, "$county", "$text");\n!;
          }
        $script_html .= "}\n";
      }
      $script_html .= "}\n";
    }
  }

  $script_html .= <<END;
    }
    </SCRIPT>
END

  my $county_html = $script_html;
  if ( $countyflag ) {
    $county_html .= qq!<SELECT NAME="${prefix}county" onChange="$param->{'onchange'}">!;
    foreach my $county ( 
      sort keys %{ $cust_main_county{$param->{'selected_country'}}{$param->{'selected_state'}} }
    ) {
      my $text = $county || '(n/a)';
      $county_html .= qq!<OPTION VALUE="$county"!.
                      ($county eq $param->{'selected_county'} ? 
                        ' SELECTED>' : 
                        '>'
                      ).
                      $text.
                      '</OPTION>';
    }
    $county_html .= '</SELECT>';
  } else {
    $county_html .=
      qq!<INPUT TYPE="hidden" NAME="${prefix}county" VALUE="$param->{'selected_county'}">!;
  }

  my $state_html = qq!<SELECT NAME="${prefix}state" !.
                   qq!onChange="${prefix}state_changed(this); $param->{'onchange'}">!;
  foreach my $state ( sort keys %{ $cust_main_county{$param->{'selected_country'}} } ) {
    my $text = $state || '(n/a)';
    my $selected = $state eq $param->{'selected_state'} ? 'SELECTED' : '';
    $state_html .= "\n<OPTION $selected VALUE=$state>$text</OPTION>"
  }
  $state_html .= '</SELECT>';

  my $country_html = '';
  if ( scalar( keys %cust_main_county ) > 1 )  {

    $country_html = qq(<SELECT NAME="${prefix}country" ).
                    qq(onChange="${prefix}country_changed(this); ).
                                 $param->{'onchange'}.
                               '"'.
                      '>';
    my $countrydefault = $param->{default_country} || 'US';
    foreach my $country (
      sort { ($b eq $countrydefault) <=> ($a eq $countrydefault) or $a cmp $b }
        keys %cust_main_county
    ) {
      my $selected = $country eq $param->{'selected_country'}
                       ? ' SELECTED'
                       : '';
      $country_html .= "\n<OPTION$selected>$country</OPTION>"
    }
    $country_html .= '</SELECT>';
  } else {

    $country_html = qq(<INPUT TYPE="hidden" NAME="${prefix}country" ).
                            ' VALUE="'. (keys %cust_main_county )[0]. '">';

  }

  ($county_html, $state_html, $country_html);

}

sub regionselector_hashref {
  my ($county_html, $state_html, $country_html) = regionselector(@_);
  {
    'county_html'  => $county_html,
    'state_html'   => $state_html,
    'country_html' => $country_html,
  };
}

=item location_form HASHREF | LIST

Takes as input a hashref or list of key/value pairs with the following keys:

=over 4

=item session_id

Current customer session_id

=item no_asterisks

Omit red asterisks from required fields.

=item address1_label

Label for first address line.

=back

Returns an HTML fragment for a location form (address, city, state, zip,
country)

=cut

sub location_form {
  my $param;
  if ( ref($_[0]) ) {
    $param = shift;
  } else {
    $param = { @_ };
  }

  my $session_id = delete $param->{'session_id'};

  my $rv = mason_comp( 'session_id' => $session_id,
                       'comp'       => '/elements/location.html',
                       'args'       => [ %$param ],
                     );

  #hmm.
  $rv->{'error'} || $rv->{'output'};

}


#=item expselect HASHREF | LIST
#
#Takes as input a hashref or list of key/value pairs with the following keys:
#
#=over 4
#
#=item prefix - Specify a unique prefix string  if you intend to use the HTML output multiple time son one page.
#
#=item date - current date, in yyyy-mm-dd or m-d-yyyy format
#
#=back

=item expselect PREFIX [ DATE ]

Takes as input a unique prefix string and the current expiration date, in
yyyy-mm-dd or m-d-yyyy format

Returns an HTML fragments for expiration date selection.

=cut

sub expselect {
  #my $param;
  #if ( ref($_[0]) ) {
  #  $param = shift;
  #} else {
  #  $param = { @_ };
  #my $prefix = $param->{'prefix'};
  #my $prefix = exists($param->{'prefix'}) ? $param->{'prefix'} : '';
  #my $date =   exists($param->{'date'})   ? $param->{'date'}   : '';
  my $prefix = shift;
  my $date = scalar(@_) ? shift : '';

  my( $m, $y ) = ( 0, 0 );
  if ( $date  =~ /^(\d{4})-(\d{2})-\d{2}$/ ) { #PostgreSQL date format
    ( $m, $y ) = ( $2, $1 );
  } elsif ( $date =~ /^(\d{1,2})-(\d{1,2}-)?(\d{4}$)/ ) {
    ( $m, $y ) = ( $1, $3 );
  }
  my $return = qq!<SELECT NAME="$prefix!. qq!_month" SIZE="1">!;
  for ( 1 .. 12 ) {
    $return .= qq!<OPTION VALUE="$_"!;
    $return .= " SELECTED" if $_ == $m;
    $return .= ">$_";
  }
  $return .= qq!</SELECT>/<SELECT NAME="$prefix!. qq!_year" SIZE="1">!;
  my @t = localtime;
  my $thisYear = $t[5] + 1900;
  for ( ($thisYear > $y && $y > 0 ? $y : $thisYear) .. ($thisYear+10) ) {
    $return .= qq!<OPTION VALUE="$_"!;
    $return .= " SELECTED" if $_ == $y;
    $return .= ">$_";
  }
  $return .= "</SELECT>";

  $return;
}

=item popselector HASHREF | LIST

Takes as input a hashref or list of key/value pairs with the following keys:

=over 4

=item popnum

Access number number

=item pops

An arrayref of hash references specifying access numbers.  Normally you can just pass the value of the I<svc_acct_pop> field returned by B<signup_info>.

=back

Returns an HTML fragment for access number selection.

=cut

#horrible false laziness with FS/FS/svc_acct_pop.pm::popselector
sub popselector {
  my $param;
  if ( ref($_[0]) ) {
    $param = shift;
  } else {
    $param = { @_ };
  }
  my $popnum = $param->{'popnum'};
  my $pops = $param->{'pops'};

  return '<INPUT TYPE="hidden" NAME="popnum" VALUE="">' unless @$pops;
  return $pops->[0]{city}. ', '. $pops->[0]{state}.
         ' ('. $pops->[0]{ac}. ')/'. $pops->[0]{exch}. '-'. $pops->[0]{loc}.
         '<INPUT TYPE="hidden" NAME="popnum" VALUE="'. $pops->[0]{popnum}. '">'
    if scalar(@$pops) == 1;

  my %pop = ();
  my %popnum2pop = ();
  foreach (@$pops) {
    push @{ $pop{ $_->{state} }->{ $_->{ac} } }, $_;
    $popnum2pop{$_->{popnum}} = $_;
  }

  my $text = <<END;
    <SCRIPT>
    function opt(what,href,text) {
      var optionName = new Option(text, href, false, false)
      var length = what.length;
      what.options[length] = optionName;
    }
END

  my $init_popstate = $param->{'init_popstate'};
  if ( $init_popstate ) {
    $text .= '<INPUT TYPE="hidden" NAME="init_popstate" VALUE="'.
             $init_popstate. '">';
  } else {
    $text .= <<END;
      function acstate_changed(what) {
        state = what.options[what.selectedIndex].text;
        what.form.popac.options.length = 0
        what.form.popac.options[0] = new Option("Area code", "-1", false, true);
END
  } 

  my @states = $init_popstate ? ( $init_popstate ) : keys %pop;
  foreach my $state ( sort { $a cmp $b } @states ) {
    $text .= "\nif ( state == \"$state\" ) {\n" unless $init_popstate;

    foreach my $ac ( sort { $a cmp $b } keys %{ $pop{$state} }) {
      $text .= "opt(what.form.popac, \"$ac\", \"$ac\");\n";
      if ($ac eq $param->{'popac'}) {
        $text .= "what.form.popac.options[what.form.popac.length-1].selected = true;\n";
      }
    }
    $text .= "}\n" unless $init_popstate;
  }
  $text .= "popac_changed(what.form.popac)}\n";

  $text .= <<END;
  function popac_changed(what) {
    ac = what.options[what.selectedIndex].text;
    what.form.popnum.options.length = 0;
    what.form.popnum.options[0] = new Option("City", "-1", false, true);

END

  foreach my $state ( @states ) {
    foreach my $popac ( keys %{ $pop{$state} } ) {
      $text .= "\nif ( ac == \"$popac\" ) {\n";

      foreach my $pop ( @{$pop{$state}->{$popac}}) {
        my $o_popnum = $pop->{popnum};
        my $poptext =  $pop->{city}. ', '. $pop->{state}.
                       ' ('. $pop->{ac}. ')/'. $pop->{exch}. '-'. $pop->{loc};

        $text .= "opt(what.form.popnum, \"$o_popnum\", \"$poptext\");\n";
        if ($popnum == $o_popnum) {
          $text .= "what.form.popnum.options[what.form.popnum.length-1].selected = true;\n";
        }
      }
      $text .= "}\n";
    }
  }


  $text .= "}\n</SCRIPT>\n";

  $param->{'acstate'} = '' unless defined($param->{'acstate'});

  $text .=
    qq!<TABLE CELLPADDING="0"><TR><TD><SELECT NAME="acstate"! .
    qq!SIZE=1 onChange="acstate_changed(this)"><OPTION VALUE=-1>State!;
  $text .= "<OPTION" . ($_ eq $param->{'acstate'} ? " SELECTED" : "") .
           ">$_" foreach sort { $a cmp $b } @states;
  $text .= '</SELECT>'; #callback? return 3 html pieces?  #'</TD>';

  $text .=
    qq!<SELECT NAME="popac" SIZE=1 onChange="popac_changed(this)">!.
    qq!<OPTION>Area code</SELECT></TR><TR VALIGN="top">!;

  $text .= qq!<TR><TD><SELECT NAME="popnum" SIZE=1 STYLE="width: 20em"><OPTION>City!;


  #comment this block to disable initial list polulation
  my @initial_select = ();
  if ( scalar( @$pops ) > 100 ) {
    push @initial_select, $popnum2pop{$popnum} if $popnum2pop{$popnum};
  } else {
    @initial_select = @$pops;
  }
  foreach my $pop ( sort { $a->{state} cmp $b->{state} } @initial_select ) {
    $text .= qq!<OPTION VALUE="!. $pop->{popnum}. '"'.
             ( ( $popnum && $pop->{popnum} == $popnum ) ? ' SELECTED' : '' ). ">".
             $pop->{city}. ', '. $pop->{state}.
               ' ('. $pop->{ac}. ')/'. $pop->{exch}. '-'. $pop->{loc};
  }

  $text .= qq!</SELECT></TD></TR></TABLE>!;

  $text;

}

=item domainselector HASHREF | LIST

Takes as input a hashref or list of key/value pairs with the following keys:

=over 4

=item pkgnum

Package number

=item domsvc

Service number of the selected item.

=back

Returns an HTML fragment for domain selection.

=cut

sub domainselector {
  my $param;
  if ( ref($_[0]) ) {
    $param = shift;
  } else {
    $param = { @_ };
  }
  my $domsvc= $param->{'domsvc'};
  my $rv = 
      domain_select_hash(map {$_ => $param->{$_}} qw(pkgnum svcpart pkgpart) );
  my $domains = $rv->{'domains'};
  $domsvc = $rv->{'domsvc'} unless $domsvc;

  return '<INPUT TYPE="hidden" NAME="domsvc" VALUE="">'
    unless scalar(keys %$domains);

  if (scalar(keys %$domains) == 1) {
    my $key;
    foreach(keys %$domains) {
      $key = $_;
    }
    return '<TR><TD ALIGN="right">Domain</TD><TD>'. $domains->{$key}.
           '<INPUT TYPE="hidden" NAME="domsvc" VALUE="'. $key. '"></TD></TR>'
  }

  my $text .= qq!<TR><TD ALIGN="right">Domain</TD><TD><SELECT NAME="domsvc" SIZE=1 STYLE="width: 20em">!;

  $text .= '<OPTION>(Choose Domain)' unless $domsvc;

  foreach my $domain ( sort { $domains->{$a} cmp $domains->{$b} } keys %$domains ) {
    $text .= qq!<OPTION VALUE="!. $domain. '"'.
             ( ( $domsvc && $domain == $domsvc ) ? ' SELECTED' : '' ). ">".
             $domains->{$domain};
  }

  $text .= qq!</SELECT></TD></TR>!;

  $text;

}

=item didselector HASHREF | LIST

Takes as input a hashref or list of key/value pairs with the following keys:

=over 4

=item field

Field name for the returned HTML fragment.

=item svcpart

Service definition (see L<FS::part_svc>)

=back

Returns an HTML fragment for DID selection.

=cut

sub didselector {
  my $param;
  if ( ref($_[0]) ) {
    $param = shift;
  } else {
    $param = { @_ };
  }

  my $rv = mason_comp( 'comp'=>'/elements/select-did.html',
                       'args'=>[ %$param ],
                     );

  #hmm.
  $rv->{'error'} || $rv->{'output'};

}

=back

=head1 RESELLER FUNCTIONS

Note: Resellers can also use the B<signup_info> and B<new_customer> functions
with their active session, and the B<customer_info> and B<order_pkg> functions
with their active session and an additional I<custnum> parameter.

For the most part, development of the reseller web interface has been
superceded by agent-virtualized access to the backend.

=over 4

=item agent_login

Agent login

=item agent_info

Agent info

=item agent_list_customers

List agent's customers.

=back

=head1 BUGS

=head1 SEE ALSO

L<freeside-selfservice-clientd>, L<freeside-selfservice-server>

=cut

1;

