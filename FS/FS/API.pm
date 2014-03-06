package FS::API;

use FS::Conf;
use FS::Record qw( qsearchs );
use FS::cust_main;

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

#Customer data
# pull customer info 
# The fields needed are:
#
# cust_main.custnum
# cust_main.first
# cust_main.last
# cust_main.company
# cust_main.address1
# cust_main.address2
# cust_main.city
# cust_main.state
# cust_main.zip
# cust_main.daytime
# cust_main.night
# cust_main_invoice.dest
#
# at minimum

#Customer balances

#Advertising sources?

# "2 way syncing" ?  start with non-sync pulling info here, then if necessary
# figure out how to trigger something when those things change

# long-term: package changes?

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

  return \%return;

}

=back

1;
