package FS::SelfService;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK $socket %autoload $tag);
use Exporter;
use Socket;
use FileHandle;
#use IO::Handle;
use IO::Select;
use Storable qw(nstore_fd fd_retrieve);

$VERSION = '0.03';

@ISA = qw( Exporter );

$socket =  "/usr/local/freeside/selfservice_socket";
$socket .= '.'.$tag if defined $tag && length($tag);

#maybe should ask ClientAPI for this list
%autoload = (
  'passwd'          => 'passwd/passwd',
  'chfn'            => 'passwd/passwd',
  'chsh'            => 'passwd/passwd',
  'login'           => 'MyAccount/login',
  'customer_info'   => 'MyAccount/customer_info',
  'edit_info'       => 'MyAccount/edit_info',
  'invoice'         => 'MyAccount/invoice',
  'cancel'          => 'MyAccount/cancel',
  'payment_info'    => 'MyAccount/payment_info',
  'process_payment' => 'MyAccount/process_payment',
  'list_pkgs'       => 'MyAccount/list_pkgs',
  'order_pkg'       => 'MyAccount/order_pkg',
  'cancel_pkg'      => 'MyAccount/cancel_pkg',
  'signup_info'     => 'Signup/signup_info',
  'new_customer'    => 'Signup/new_customer',
);
@EXPORT_OK = keys %autoload;

$ENV{'PATH'} ='/usr/bin:/usr/ucb:/bin';
$ENV{'SHELL'} = '/bin/sh';
$ENV{'IFS'} = " \t\n";
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'} = '';

my $freeside_uid = scalar(getpwnam('freeside'));
die "not running as the freeside user\n" if $> != $freeside_uid;

foreach my $autoload ( keys %autoload ) {

  my $eval =
  "sub $autoload { ". '
                   my $param;
                   if ( ref($_[0]) ) {
                     $param = shift;
                   } else {
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
  socket(SOCK, PF_UNIX, SOCK_STREAM, 0) or die "socket: $!";
  connect(SOCK, sockaddr_un($socket)) or die "connect: $!";
  nstore_fd($packet, \*SOCK) or die "can't send packet: $!";
  SOCK->flush;

  #shoudl trap: Magic number checking on storable file failed at blib/lib/Storable.pm (autosplit into blib/lib/auto/Storable/fd_retrieve.al) line 337, at /usr/local/share/perl/5.6.1/FS/SelfService.pm line 71

  #block until there is a message on socket
#  my $w = new IO::Select;
#  $w->add(\*SOCK);
#  my @wait = $w->can_read;
  my $return = fd_retrieve(\*SOCK) or die "error reading result: $!";
  die $return->{'_error'} if defined $return->{_error} && $return->{_error};

  $return;
}

=head1 NAME

FS::SelfService - Freeside self-service API

=head1 SYNOPSIS

  # password and shell account changes
  use FS::SelfService qw(passwd chfn chsh);

  # "my account" functionality
  use FS::SelfService qw( login customer_info invoice cancel payment_info process_payment );

  my $rv = login( { 'username' => $username,
                    'domain'   => $domain,
                    'password' => $password,
                  }
                );

  if ( $rv->{'error'} ) {
    #handle login error...
  } else {
    #successful login
    my $session_id = $rv->{'session_id'};
  }

  my $customer_info = customer_info( { 'session_id' => $session_id } );

  #payment_info and process_payment are available in 1.5+ only
  my $payment_info = payment_info( { 'session_id' => $session_id } );

  #!!! process_payment example

  #!!! list_pkgs example

  #!!! order_pkg example

  #!!! cancel_pkg example

  # signup functionality
  use FS::SelfService qw( signup_info new_customer );

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
                        'paydate'          => $paydate,
                        'payname'          => $payname,
                        'invoicing_list'   => $invoicing_list,
                        'referral_custnum' => $referral_custnum,
                        'pkgpart'          => $pkgpart,
                        'username'         => $username,
                        '_password'        => $password,
                        'popnum'           => $popnum,
                        'agentnum'         => $agentnum,
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

=item chfn

=item chsh

=back

=head1 "MY ACCOUNT" FUNCTIONS

=over 4

=item login HASHREF

Creates a user session.  Takes a hash reference as parameter with the
following keys:

=over 4

=item username

=item domain

=item password

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

=item The following fields are also returned: first last company address1 address2 city county state zip country daytime night fax ship_first ship_last ship_company ship_address1 ship_address2 ship_city ship_state ship_zip ship_country ship_daytime ship_night ship_fax

=back

=item edit_info HASHREF

Takes a hash reference as parameter with any of the following keys:

first last company address1 address2 city county state zip country daytime night fax ship_first ship_last ship_company ship_address1 ship_address2 ship_city ship_state ship_zip ship_country ship_daytime ship_night ship_fax

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

=item address2

=item city

=item state

=item zip

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

=item paybatch

Unique transaction identifier (prevents multiple charges), passed to the
process_payment function

=back

=item process_payment HASHREF

Processes a payment and possible change of address or payment type.  Takes a
hash reference as parameter with the following keys:

=over 4

=item session_id

=item save

If true, address and card information entered will be saved for subsequent
transactions.

=item auto

If true, future credit card payments will be done automatically (sets payby to
CARD).  If false, future credit card payments will be done on-demand (sets
payby to DCRD).  This option only has meaning if B<save> is set true.  

=item payname

=item address1

=item address2

=item city

=item state

=item zip

=item payinfo

Card number

=item month

Card expiration month

=item year

Card expiration year

=item paybatch

Unique transaction identifier, returned from the payment_info function.
Prevents multiple charges.

=back

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors

=item list_pkgs

Returns package information for this customer.

Takes a hash reference as parameter with a single key: B<session_id>

Returns a hash reference containing customer package information.  The hash reference contains the following keys:

=over 4

=item cust_pkg HASHREF

Array reference of hash references, each of which has the fields of a cust_pkg record (see L<FS::cust_pkg>).  Note these are not FS::cust_pkg objects, but hash references of columns and values.

=back

=item order_pkg

Orders a package for this customer.

Takes a hash reference as parameter with the following keys:

=over 4

=item session_id

=item pkgpart

=item svcpart

optional svcpart, required only if the package definition does not contain
one svc_acct service definition with quantity 1 (it may contain others with
quantity >1)

=item username

=item _password

=item sec_phrase

=item popnum

=back

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors.  The special error '_decline' is returned for
declined transactions.

=item cancel_pkg

Cancels a package for this customer.

Takes a hash reference as parameter with the following keys:

=over 4

=item session_id

=item pkgpart

=back

Returns a hash reference with a single key, B<error>, empty on success, or an
error message on errors.

=back

=head1 SIGNUP FUNCTIONS

=over 4

=item signup_info

Returns a hash reference containing information that may be useful in
displaying a signup page.  The hash reference contains the following keys:

=over 4

=item cust_main_county

County/state/country data - array reference of hash references, each of which has the fields of a cust_main_county record (see L<FS::cust_main_county>).  Note these are not FS::cust_main_county objects, but hash references of columns and values.

=item part_pkg

Available packages - array reference of hash references, each of which has the fields of a part_pkg record (see L<FS::part_pkg>).  Each hash reference also has an additional 'payby' field containing an array reference of acceptable payment types specific to this package (see below and L<FS::part_pkg/payby>).  Note these are not FS::part_pkg objects, but hash references of columns and values.  Requires the 'signup_server-default_agentnum' configuration value to be set.

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

=item CARD (credit card - automatic)

=item DCRD (credit card - on-demand - version 1.5+ only)

=item CHEK (electronic check - automatic)

=item DCHK (electronic check - on-demand - version 1.5+ only)

=item LECB (Phone bill billing)

=item BILL (billing, not recommended for signups)

=item COMP (free, definately not recommended for signups)

=item PREPAY (special billing type: applies a credit (see FS::prepay_credit) and sets billing type to BILL)

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

=item new_customer HASHREF

Creates a new customer.  Takes a hash reference as parameter with the
following keys:

=over 4

=item first - first name (required)

=item last - last name (required)

=item ss (not typically collected; mostly used for ACH transactions)

=item company

=item address1 (required)

=item address2

=item city (required)

=item county

=item state (required)

=item zip (required)

=item daytime - phone

=item night - phone

=item fax - phone

=item payby - CARD, DCRD, CHEK, DCHK, LECB, BILL, COMP or PREPAY (see L</signup_info> (required)

=item payinfo - Card number for CARD/DCRD, account_number@aba_number for CHEK/DCHK, prepaid "pin" for PREPAY, purchase order number for BILL

=item paycvv - Credit card CVV2 number (1.5+ or 1.4.2 with CVV schema patch)

=item paydate - Expiration date for CARD/DCRD

=item payname - Exact name on credit card for CARD/DCRD, bank name for CHEK/DCHK

=item invoicing_list - comma-separated list of email addresses for email invoices.  The special value 'POST' is used to designate postal invoicing (it may be specified alone or in addition to email addresses),

=item referral_custnum - referring customer number

=item pkgpart - pkgpart of initial package

=item username

=item _password

=item sec_phrase - security phrase

=item popnum - access number (index, not the literal number)

=item agentnum - agent number

=back

Returns a hash reference with the following keys:

=over 4

=item error Empty on success, or an error message on errors.  The special error '_decline' is returned for declined transactions; other error messages should be suitable for display to the user (and are customizable in under Sysadmin | View/Edit message catalog)

=back


=back

=head1 BUGS

=head1 SEE ALSO

L<freeside-selfservice-clientd>, L<freeside-selfservice-server>

=cut

1;

