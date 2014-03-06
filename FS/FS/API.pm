package FS::API;

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
channel (for exampple, with an SSH tunnel or VPN) rather than accessing it
in plaintext.

=head1 METHODS

=over 4

=item insert_payment

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

=item insert_credit

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

=item insert_refund

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

=item new_customer

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
 
  #same for refnum like signup_server-default_refnum

  my $cust_main = new FS::cust_main ( {
      'agentnum'      => $agentnum,
      'refnum'        => $opt{refnum}
                         || $conf->config('signup_server-default_refnum'),
      'payby'         => 'BILL',

      map { $_ => $opt{$_} } qw(
        agentnum refnum agent_custid referral_custnum
        last first company 
        daytime night fax mobile
        payby payinfo paydate paycvv payname
      ),

  } );

  my @invoicing_list = $opt{'invoicing_list'}
                         ? split( /\s*\,\s*/, $opt{'invoicing_list'} )
                         : ();
  push @invoicing_list, 'POST' if $opt{'postal_invoicing'};

  my ($bill_hash, $ship_hash);
  foreach my $f (FS::cust_main->location_fields) {
    # avoid having to change this in front-end code
    $bill_hash->{$f} = $opt{"bill_$f"} || $opt{$f};
    $ship_hash->{$f} = $opt{"ship_$f"};
  }

  my $bill_location = FS::cust_location->new($bill_hash);
  my $ship_location;
  # we don't have an equivalent of the "same" checkbox in selfservice^Wthis API
  # so is there a ship address, and if so, is it different from the billing 
  # address?
  if ( length($ship_hash->{address1}) > 0 and
          grep { $bill_hash->{$_} ne $ship_hash->{$_} } keys(%$ship_hash)
         ) {

    $ship_location = FS::cust_location->new( $ship_hash );
  
  } else {
    $ship_location = $bill_location;
  }

  $cust_main->set('bill_location' => $bill_location);
  $cust_main->set('ship_location' => $ship_location);

  $error = $cust_main->insert( {}, \@invoicing_list );
  return { 'error'   => $error } if $error;
  
  return { 'error'   => '',
           'custnum' => $cust_main->custnum,
         };

}

=item customer_info

=cut

#some false laziness w/ClientAPI::Myaccount customer_info/customer_info_short

use vars qw( @cust_main_editable_fields @location_editable_fields );
@cust_main_editable_fields = qw(
  first last company daytime night fax mobile
);
#  locale
#  payby payinfo payname paystart_month paystart_year payissue payip
#  ss paytype paystate stateid stateid_state
@location_editable_fields = qw(
  address1 address2 city county state zip country
);

sub customer_info {
  my( $class, %opt ) = @_;
  my $conf = new FS::Conf;
  return { 'error' => 'Incorrect shared secret' }
    unless $opt{secret} eq $conf->config('api_shared_secret');

  my $cust_main = qsearchs('cust_main', { 'custnum' => $opt{custnum} })
    or return { 'error' => 'Unknown custnum' };

  my %return = (
    'error'           => '',
    'display_custnum' => $cust_main->display_custnum,
    'name'            => $cust_main->first. ' '. $cust_main->get('last'),
    'balance'         => $cust_main->balance,
    'status'          => $cust_main->status,
    'statuscolor'     => $cust_main->statuscolor,
  );

  $return{$_} = $cust_main->get($_)
    foreach @cust_main_editable_fields;

  for (@location_editable_fields) {
    $return{$_} = $cust_main->bill_location->get($_)
      if $cust_main->bill_locationnum;
    $return{'ship_'.$_} = $cust_main->ship_location->get($_)
      if $cust_main->ship_locationnum;
  }

  my @invoicing_list = $cust_main->invoicing_list;
  $return{'invoicing_list'} =
    join(', ', grep { $_ !~ /^(POST|FAX)$/ } @invoicing_list );
  $return{'postal_invoicing'} =
    0 < ( grep { $_ eq 'POST' } @invoicing_list );

  #generally, the more useful data from the cust_main record the better.
  # well, tell me what you want

  return \%return;

}

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

#Advertising sources?

=back

1;
