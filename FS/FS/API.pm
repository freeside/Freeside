package FS::API;

use strict;
use FS::Conf;
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::cust_location;
use FS::cust_pay;
use FS::cust_credit;
use FS::cust_refund;

=head1 NAME

FS::API - Freeside backend API

=head1 SYNOPSIS

  use FS::API;

=head1 DESCRIPTION

This module implements a backend API for advanced back-office integration.

In contrast to the self-service API, which authenticates an end-user and offers
functionality to that end user, the backend API performs a simple shared-secret
authentication and offers full, administrator functionality, enabling
integration with other back-office systems.

If accessing this API remotely with XML-RPC or JSON-RPC, be careful to block
the port by default, only allow access from back-office servers with the same
security precations as the Freeside server, and encrypt the communication
channel (for example, with an SSH tunnel or VPN) rather than accessing it
in plaintext.

=head1 METHODS

=over 4

=item insert_payment OPTION => VALUE, ...

Adds a new payment to a customers account. Takes a list of keys and values as
paramters with the following keys:

=over 5

=item secret

API Secret

=item custnum

Customer number

=item payby

Payment type

=item paid

Amount paid

=item _date

Option date for payment

=back

Example:

  my $result = FS::API->insert_payment(
    'secret'  => 'sharingiscaring',
    'custnum' => 181318,
    'payby'   => 'CASH',
    'paid'    => '54.32',

    #optional
    '_date'   => 1397977200, #UNIX timestamp
  );

  if ( $result->{'error'} ) {
    die $result->{'error'};
  } else {
    #payment was inserted
    print "paynum ". $result->{'paynum'};
  }

=cut

#enter cash payment
sub insert_payment {
  my($class, %opt) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  #less "raw" than this?  we are the backoffice API, and aren't worried
  # about version migration ala cust_main/cust_location here
  my $cust_pay = new FS::cust_pay { %opt };
  my $error = $cust_pay->insert( 'manual'=>1 );
  return { 'error'  => $error,
           'paynum' => $cust_pay->paynum,
         };
}

# pass the phone number ( from svc_phone ) 
sub insert_payment_phonenum {
  my($class, %opt) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  $class->_by_phonenum('insert_payment', %opt);

}

sub _by_phonenum {
  my($class, $method, %opt) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  my $phonenum = delete $opt{'phonenum'};

  my $svc_phone = qsearchs('svc_phone', { 'phonenum' => $phonenum } )
    or return { 'error' => 'Unknown phonenum' };

  my $cust_pkg = $svc_phone->cust_svc->cust_pkg
    or return { 'error' => 'Unlinked phonenum' };

  $opt{'custnum'} = $cust_pkg->custnum;

  $class->$method(%opt);

}

=item insert_credit OPTION => VALUE, ...

Adds a a credit to a customers account.  Takes a list of keys and values as
parameters with the following keys

=over 

=item secret

API Secret

=item custnum

customer number

=item amount

Amount of the credit

=item _date

The date the credit will be posted

=back

Example:

  my $result = FS::API->insert_credit(
    'secret'  => 'sharingiscaring',
    'custnum' => 181318,
    'amount'  => '54.32',

    #optional
    '_date'   => 1397977200, #UNIX timestamp
  );

  if ( $result->{'error'} ) {
    die $result->{'error'};
  } else {
    #credit was inserted
    print "crednum ". $result->{'crednum'};
  }

=cut

#Enter credit
sub insert_credit {
  my($class, %opt) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  $opt{'reasonnum'} ||= $conf->config('api_credit_reason');

  #less "raw" than this?  we are the backoffice API, and aren't worried
  # about version migration ala cust_main/cust_location here
  my $cust_credit = new FS::cust_credit { %opt };
  my $error = $cust_credit->insert;
  return { 'error'  => $error,
           'crednum' => $cust_credit->crednum,
         };
}

# pass the phone number ( from svc_phone ) 
sub insert_credit_phonenum {
  my($class, %opt) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  $class->_by_phonenum('insert_credit', %opt);

}

=item insert_refund OPTION => VALUE, ...

Adds a a credit to a customers account.  Takes a list of keys and values as
parmeters with the following keys: custnum, payby, refund

Example:

  my $result = FS::API->insert_refund(
    'secret'  => 'sharingiscaring',
    'custnum' => 181318,
    'payby'   => 'CASH',
    'refund'  => '54.32',

    #optional
    '_date'   => 1397977200, #UNIX timestamp
  );

  if ( $result->{'error'} ) {
    die $result->{'error'};
  } else {
    #refund was inserted
    print "refundnum ". $result->{'crednum'};
  }

=cut

#Enter cash refund.
sub insert_refund {
  my($class, %opt) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  # when github pull request #24 is merged,
  #  will have to change over to default reasonnum like credit
  # but until then, this will do
  $opt{'reason'} ||= 'API refund';

  #less "raw" than this?  we are the backoffice API, and aren't worried
  # about version migration ala cust_main/cust_location here
  my $cust_refund = new FS::cust_refund { %opt };
  my $error = $cust_refund->insert;
  return { 'error'     => $error,
           'refundnum' => $cust_refund->refundnum,
         };
}

# pass the phone number ( from svc_phone ) 
sub insert_refund_phonenum {
  my($class, %opt) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  $class->_by_phonenum('insert_refund', %opt);

}

#---

# "2 way syncing" ?  start with non-sync pulling info here, then if necessary
# figure out how to trigger something when those things change

# long-term: package changes?

=item new_customer OPTION => VALUE, ...

Creates a new customer. Takes a list of keys and values as parameters with the
following keys:

=over 4

=item secret

API Secret

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

=item city (required)

City

=item county

County

=item state (required)

State

=item zip (required)

Zip or postal code

=item country

2 Digit Country Code

=item latitude

latitude

=item Longitude

longitude

=item geocode

Currently used for third party tax vendor lookups

=item censustract

Used for determining FCC 477 reporting

=item censusyear

Used for determining FCC 477 reporting

=item daytime

Daytime phone number

=item night

Evening phone number

=item fax

Fax number

=item mobile

Mobile number

=item invoicing_list

comma-separated list of email addresses for email invoices. The special value 'POST' is used to designate postal invoicing (it may be specified alone or in addition to email addresses),
postal_invoicing
Set to 1 to enable postal invoicing

=item payby

CARD, DCRD, CHEK, DCHK, LECB, BILL, COMP or PREPAY

=item payinfo

Card number for CARD/DCRD, account_number@aba_number for CHEK/DCHK, prepaid "pin" for PREPAY, purchase order number for BILL

=item paycvv

Credit card CVV2 number (1.5+ or 1.4.2 with CVV schema patch)

=item paydate

Expiration date for CARD/DCRD

=item payname

Exact name on credit card for CARD/DCRD, bank name for CHEK/DCHK

=item referral_custnum

Referring customer number

=item salesnum

Sales person number

=item agentnum

Agent number

=item agent_custid

Agent specific customer number

=item referral_custnum

Referring customer number

=back

=cut

#certainly false laziness w/ClientAPI::Signup new_customer/new_customer_minimal
# but approaching this from a clean start / back-office perspective
#  i.e. no package/service, no immediate credit card run, etc.

sub new_customer {
  my( $class, %opt ) = @_;

  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  #default agentnum like signup_server-default_agentnum?
  #$opt{agentnum} ||= $conf->config('signup_server-default_agentnum');
 
  #same for refnum like signup_server-default_refnum
  $opt{refnum} ||= $conf->config('signup_server-default_refnum');

  $class->API_insert( %opt );
}

=item update_customer
Updates an existing customer. Passing an empty value clears that field, while NOT passing that key/value at all leaves it alone.
Takes a hash reference as parameter with the following keys:

=over 4

=item secret

API Secret (required)

=item custnum

Customer number (required)

=item first

first name 

=item last

last name 

=item company

Company name

=item address1 

Address line one

=item city 

City

=item county

County

=item state 

State

=item zip 

Zip or postal code

=item country

2 Digit Country Code

=item daytime

Daytime phone number

=item night

Evening phone number

=item fax

Fax number

=item mobile

Mobile number

=item invoicing_list

comma-separated list of email addresses for email invoices. The special value '$
postal_invoicing
Set to 1 to enable postal invoicing

=item payby

CARD, DCRD, CHEK, DCHK, LECB, BILL, COMP or PREPAY

=item payinfo

Card number for CARD/DCRD, account_number@aba_number for CHEK/DCHK, prepaid "pi$

=item paycvv

Credit card CVV2 number (1.5+ or 1.4.2 with CVV schema patch)

=item paydate

Expiration date for CARD/DCRD

=item payname

Exact name on credit card for CARD/DCRD, bank name for CHEK/DCHK

=item referral_custnum

Referring customer number

=item salesnum

Sales person number

=item agentnum

Agent number

=back

=cut

sub update_customer {
  my( $class, %opt ) = @_;

  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  FS::cust_main->API_update( %opt );
}

=item customer_info OPTION => VALUE, ...

Returns general customer information. Takes a list of keys and values as
parameters with the following keys: custnum, secret 

=cut

sub customer_info {
  my( $class, %opt ) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  my $cust_main = qsearchs('cust_main', { 'custnum' => $opt{custnum} })
    or return { 'error' => 'Unknown custnum' };

  $cust_main->API_getinfo;
}

=item location_info

Returns location specific information for the customer. Takes a list of keys
and values as paramters with the following keys: custnum, secret

=cut

#I also monitor for changes to the additional locations that are applied to
# packages, and would like for those to be exportable as well.  basically the
# location data passed with the custnum.

sub location_info {
  my( $class, %opt ) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  my @cust_location = qsearch('cust_location', { 'custnum' => $opt{custnum} });

  my %return = (
    'error'           => '',
    'locations'       => [ map $_->hashref, @cust_location ],
  );

  return \%return;
}

=item bill_now OPTION => VALUE, ...

Bills a single customer now, in the same fashion as the "Bill now" link in the
UI.

Returns a hash reference with a single key, 'error'.  If there is an error,
the value contains the error, otherwise it is empty.

=cut

sub bill_now {
  my( $class, %opt ) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  my $cust_main = qsearchs('cust_main', { 'custnum' => $opt{custnum} })
    or return { 'error' => 'Unknown custnum' };

  my $error = $cust_main->bill_and_collect( 'fatal'      => 'return',
                                            'retry'      => 1,
                                            'check_freq' =>'1d',
                                          );

   return { 'error' => $error,
          };

}


#Advertising sources?


1;
