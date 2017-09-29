package FS::API;

use strict;
use Date::Parse;
use FS::Conf;
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::cust_location;
use FS::cust_pay;
use FS::cust_credit;
use FS::cust_refund;
use FS::cust_pkg;

=head1 NAME

FS::API - Freeside backend API

=head1 SYNOPSIS

  use Frontier::Client;
  use Data::Dumper;

  my $url = new URI 'http://localhost:8008/'; #or if accessing remotely, secure
                                              # the traffic

  my $xmlrpc = new Frontier::Client url=>$url;

  my $result = $xmlrpc->call( 'FS.API.customer_info',
                                'secret'  => 'sharingiscaring',
                                'custnum' => 181318,
                            );

  print Dumper($result);

=head1 DESCRIPTION

This module implements a backend API for advanced back-office integration.

In contrast to the self-service API, which authenticates an end-user and offers
functionality to that end user, the backend API performs a simple shared-secret
authentication and offers full, administrator functionality, enabling
integration with other back-office systems.  Only access this API from a secure 
network from other backoffice machines. DON'T use this API to create customer 
portal functionality.

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

=over 4

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

=item order_number

Optional order number

=back

Example:

  my $result = FS::API->insert_payment(
    'secret'  => 'sharingiscaring',
    'custnum' => 181318,
    'payby'   => 'CASH',
    'paid'    => '54.32',

    #optional
    '_date'   => 1397977200, #UNIX timestamp
    'order_number' => '12345',
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
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

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
  $class->_by_phonenum('insert_payment', %opt);
}

sub _by_phonenum {
  my($class, $method, %opt) = @_;
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

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
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  $opt{'reasonnum'} ||= FS::Conf->new->config('api_credit_reason');

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
  $class->_by_phonenum('insert_credit', %opt);
}

=item apply_payments_and_credits

Applies payments and credits for this customer.  Takes a list of keys and
values as parameter with the following keys:

=over 4

=item secret

API secret

=item custnum

Customer number

=back

=cut

#apply payments and credits
sub apply_payments_and_credits {
  my($class, %opt) = @_;
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  my $cust_main = qsearchs('cust_main', { 'custnum' => $opt{custnum} })
    or return { 'error' => 'Unknown custnum' };

  my $error = $cust_main->apply_payments_and_credits( 'manual'=>1 );
  return { 'error'  => $error, };
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
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

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
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  #default agentnum like signup_server-default_agentnum?
  #$opt{agentnum} ||= $conf->config('signup_server-default_agentnum');
 
  #same for refnum like signup_server-default_refnum
  $opt{refnum} ||= FS::Conf->new->config('signup_server-default_refnum');

  $class->API_insert( %opt );
}

=item update_customer

Updates an existing customer. Passing an empty value clears that field, while
NOT passing that key/value at all leaves it alone. Takes a list of keys and
values as parameters with the following keys:

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

Comma-separated list of email addresses for email invoices. The special value 
'POST' is used to designate postal invoicing (it may be specified alone or in
addition to email addresses),
postal_invoicing
Set to 1 to enable postal invoicing

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
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  FS::cust_main->API_update( %opt );
}

=item customer_info OPTION => VALUE, ...

Returns general customer information. Takes a list of keys and values as
parameters with the following keys: custnum, secret 

Example:

  use Frontier::Client;
  use Data::Dumper;

  my $url = new URI 'http://localhost:8008/'; #or if accessing remotely, secure
                                              # the traffic

  my $xmlrpc = new Frontier::Client url=>$url;

  my $result = $xmlrpc->call( 'FS.API.customer_info',
                                'secret'  => 'sharingiscaring',
                                'custnum' => 181318,
                            );

  print Dumper($result);

=cut

sub customer_info {
  my( $class, %opt ) = @_;
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  my $cust_main = qsearchs('cust_main', { 'custnum' => $opt{custnum} })
    or return { 'error' => 'Unknown custnum' };

  $cust_main->API_getinfo;
}

=item customer_list_svcs OPTION => VALUE, ...

Returns customer service information.  Takes a list of keys and values as
parameters with the following keys: custnum, secret

Example:

  use Frontier::Client;
  use Data::Dumper;

  my $url = new URI 'http://localhost:8008/'; #or if accessing remotely, secure
                                              # the traffic

  my $xmlrpc = new Frontier::Client url=>$url;

  my $result = $xmlrpc->call( 'FS.API.customer_list_svcs',
                                'secret'  => 'sharingiscaring',
                                'custnum' => 181318,
                            );

  print Dumper($result);

  foreach my $cust_svc ( @{ $result->{'cust_svc'} } ) {
    #print $cust_svc->{mac_addr}."\n" if exists $cust_svc->{mac_addr};
    print $cust_svc->{circuit_id}."\n" if exists $cust_svc->{circuit_id};
  }

=cut

sub customer_list_svcs {
  my( $class, %opt ) = @_;
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  my $cust_main = qsearchs('cust_main', { 'custnum' => $opt{custnum} })
    or return { 'error' => 'Unknown custnum' };

  #$cust_main->API_list_svcs;

  #false laziness w/ClientAPI/list_svcs

  my @cust_svc = ();
  #my @cust_pkg_usage = ();
  #foreach my $cust_pkg ( $p->{'ncancelled'} 
  #                       ? $cust_main->ncancelled_pkgs
  #                       : $cust_main->unsuspended_pkgs ) {
  foreach my $cust_pkg ( $cust_main->all_pkgs ) {
    #next if $pkgnum && $cust_pkg->pkgnum != $pkgnum;
    push @cust_svc, @{[ $cust_pkg->cust_svc ]}; #@{[ ]} to force array context
    #push @cust_pkg_usage, $cust_pkg->cust_pkg_usage;
  }

  return {
    'cust_svc' => [ map $_->API_getinfo, @cust_svc ],
  };

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
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  my @cust_location = qsearch('cust_location', { 'custnum' => $opt{custnum} });

  my %return = (
    'error'           => '',
    'locations'       => [ map $_->hashref, @cust_location ],
  );

  return \%return;
}

=item order_package OPTION => VALUE, ...

Orders a new customer package.  Takes a list of keys and values as paramaters
with the following keys:

=over 4

=item secret

API Secret

=item custnum

=item pkgpart

=item quantity

=item start_date

=item contract_end

=item address1

=item address2

=item city

=item county

=item state

=item zip

=item country

=item setup_fee

Including this implements per-customer custom pricing for this package, overriding package definition pricing

=item recur_fee

Including this implements per-customer custom pricing for this package, overriding package definition pricing

=item invoice_details

A single string for just one detail line, or an array reference of one or more
lines of detail

=cut

sub order_package {
  my( $class, %opt ) = @_;

  my $cust_main = qsearchs('cust_main', { 'custnum' => $opt{custnum} })
    or return { 'error' => 'Unknown custnum' };

  #some conceptual false laziness w/cust_pkg/Import.pm

  my $cust_pkg = new FS::cust_pkg {
    'pkgpart'    => $opt{'pkgpart'},
    'quantity'   => $opt{'quantity'} || 1,
  };

  #start_date and contract_end
  foreach my $date_field (qw( start_date contract_end )) {
    if ( $opt{$date_field} =~ /^(\d+)$/ ) {
      $cust_pkg->$date_field( $opt{$date_field} );
    } elsif ( $opt{$date_field} ) {
      $cust_pkg->$date_field( str2time( $opt{$date_field} ) );
    }
  }

  #especially this part for custom pkg price
  # (false laziness w/cust_pkg/Import.pm)
  my $s = $opt{'setup_fee'};
  my $r = $opt{'recur_fee'};
  my $part_pkg = $cust_pkg->part_pkg;
  if (    ( length($s) && $s != $part_pkg->option('setup_fee') )
       or ( length($r) && $r != $part_pkg->option('recur_fee') )
     )
  {
    my $custom_part_pkg = $part_pkg->clone;
    $custom_part_pkg->disabled('Y');
    my %options = $part_pkg->options;
    $options{'setup_fee'} = $s if length($s);
    $options{'recur_fee'} = $r if length($r);
    my $error = $custom_part_pkg->insert( options=>\%options );
    return ( 'error' => "error customizing package: $error" ) if $error;
    $cust_pkg->pkgpart( $custom_part_pkg->pkgpart );
  }

  my %order_pkg = ( 'cust_pkg' => $cust_pkg );

  my @loc_fields = qw( address1 address2 city county state zip country );
  if ( grep length($opt{$_}), @loc_fields ) {
     $order_pkg{'cust_location'} = new FS::cust_location {
       map { $_ => $opt{$_} } @loc_fields, 'custnum'
     };
  }

  $order_pkg{'invoice_details'} = $opt{'invoice_details'}
    if $opt{'invoice_details'};

  my $error = $cust_main->order_pkg( %order_pkg );

  #if ( $error ) {
    return { 'error'  => $error,
             #'pkgnum' => '',
           };
  #} else {
  #  return { 'error'  => '',
  #           #cust_main->order_pkg doesn't actually have a way to return pkgnum
  #           #'pkgnum' => $pkgnum,
  #         };
  #}

}

=item change_package_location

Updates package location. Takes a list of keys and values 
as parameters with the following keys: 

pkgnum

secret

locationnum - pass this, or the following keys (don't pass both)

locationname

address1

address2

city

county

state

zip

addr_clean

country

censustract

censusyear

location_type

location_number

location_kind

incorporated

On error, returns a hashref with an 'error' key.
On success, returns a hashref with 'pkgnum' and 'locationnum' keys,
containing the new values.

=cut

sub change_package_location {
  my $class = shift;
  my %opt  = @_;
  return _shared_secret_error() unless _check_shared_secret($opt{'secret'});

  my $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $opt{'pkgnum'} })
    or return { 'error' => 'Unknown pkgnum' };

  my %changeopt;

  foreach my $field ( qw(
    locationnum
    locationname
    address1
    address2
    city
    county
    state
    zip
    addr_clean
    country
    censustract
    censusyear
    location_type
    location_number
    location_kind
    incorporated
  )) {
    $changeopt{$field} = $opt{$field} if $opt{$field};
  }

  $cust_pkg->API_change(%changeopt);
}

=item bill_now OPTION => VALUE, ...

Bills a single customer now, in the same fashion as the "Bill now" link in the
UI.

Returns a hash reference with a single key, 'error'.  If there is an error,   
the value contains the error, otherwise it is empty. Takes a list of keys and
values as parameters with the following keys:

=over 4

=item secret

API Secret (required)

=item custnum

Customer number (required)

=back

=cut

sub bill_now {
  my( $class, %opt ) = @_;
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  my $cust_main = qsearchs('cust_main', { 'custnum' => $opt{custnum} })
    or return { 'error' => 'Unknown custnum' };

  my $error = $cust_main->bill_and_collect( 'fatal'      => 'return',
                                            'retry'      => 1,
                                            'check_freq' =>'1d',
                                          );

   return { 'error' => $error,
          };

}


#next.. Delete Advertising sources?

=item list_advertising_sources OPTION => VALUE, ...

Lists all advertising sources.

=over

=item secret

API Secret

=back

Example:

  my $result = FS::API->list_advertising_sources(
    'secret'  => 'sharingiscaring',
  );

  if ( $result->{'error'} ) {
    die $result->{'error'};
  } else {
    # list advertising sources returns an array of hashes for sources.
    print Dumper($result->{'sources'});
  }

=cut

#list_advertising_sources
sub list_advertising_sources {
  my( $class, %opt ) = @_;
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  my @sources = qsearch('part_referral', {}, '', "")
    or return { 'error' => 'No referrals' };

  my $return = {
    'sources'       => [ map $_->hashref, @sources ],
  };

  $return;
}

=item add_advertising_source OPTION => VALUE, ...

Add a new advertising source.

=over

=item secret

API Secret

=item referral

Referral name

=item disabled

Referral disabled, Y for disabled or nothing for enabled

=item agentnum

Agent ID number

=item title

External referral ID

=back

Example:

  my $result = FS::API->add_advertising_source(
    'secret'     => 'sharingiscaring',
    'referral'   => 'test referral',

    #optional
    'disabled'   => 'Y',
    'agentnum'   => '2', #agent id number
    'title'      => 'test title',
  );

  if ( $result->{'error'} ) {
    die $result->{'error'};
  } else {
    # add_advertising_source returns new source upon success.
    print Dumper($result);
  }

=cut

#add_advertising_source
sub add_advertising_source {
  my( $class, %opt ) = @_;
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  use FS::part_referral;

  my $new_source = $opt{source};

  my $source = new FS::part_referral $new_source;

  my $error = $source->insert;

  my $return = {$source->hash};
  $return = { 'error' => $error, } if $error;

  $return;
}

=item edit_advertising_source OPTION => VALUE, ...

Edit a advertising source.

=over

=item secret

API Secret

=item refnum

Referral number to edit

=item source

hash of edited source fields.

=over

=item referral

Referral name

=item disabled

Referral disabled, Y for disabled or nothing for enabled

=item agentnum

Agent ID number

=item title

External referral ID

=back

=back

Example:

  my $result = FS::API->edit_advertising_source(
    'secret'     => 'sharingiscaring',
    'refnum'     => '4', # referral number to edit
    'source'     => {
       #optional
       'referral'   => 'test referral',
       'disabled'   => 'Y',
       'agentnum'   => '2', #agent id number
       'title'      => 'test title',
    }
  );

  if ( $result->{'error'} ) {
    die $result->{'error'};
  } else {
    # edit_advertising_source returns updated source upon success.
    print Dumper($result);
  }

=cut

#edit_advertising_source
sub edit_advertising_source {
  my( $class, %opt ) = @_;
  return _shared_secret_error() unless _check_shared_secret($opt{secret});

  use FS::part_referral;

  my $refnum = $opt{refnum};
  my $source = $opt{source};

  my $old = FS::Record::qsearchs('part_referral', {'refnum' => $refnum,});
  my $new = new FS::part_referral { $old->hash };

  foreach my $key (keys %$source) {
    $new->$key($source->{$key});
  }

  my $error = $new->replace;

  my $return = {$new->hash};
  $return = { 'error' => $error, } if $error;

  $return;
}


##
# helper subroutines
##

sub _check_shared_secret {
  shift eq FS::Conf->new->config('api_shared_secret');
}

sub _shared_secret_error {
  return { 'error' => 'Incorrect shared secret' };
}

1;
