package FS::API;

use FS::Conf;
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::cust_location;

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

# needs to be able to:
Enter cash payment
Enter credit
Enter cash refund.

# would like to be able to pass the phone number ( from svc_phone ) to the API for this query.

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
        address1 address2 city county state zip country
        latitude longitude
        geocode censustract censusyear
        ship_address1 ship_address2 ship_city ship_county ship_state ship_zip ship_country
        ship_latitude ship_longitude
        daytime night fax mobile
        payby payinfo paydate paycvv payname
      ),

  } );

  my @invoicing_list = $opt{'invoicing_list'}
                         ? split( /\s*\,\s*/, $opt{'invoicing_list'} )
                         : ();
  push @invoicing_list, 'POST' if $opt{'postal_invoicing'};

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
    foreach ( @cust_main_editable_fields,
              @location_editable_fields,
              map "ship_$_", @location_editable_fields,
            );

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
