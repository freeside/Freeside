package FS::part_export::portaone;

use strict;

use base qw( FS::part_export );

use Cpanel::JSON::XS;
use Net::HTTPS::Any qw(https_post);

use FS::Conf;

=pod

=head1 NAME

FS::part_export::portaone

=head1 SYNOPSIS

PortaOne integration for Freeside

=head1 DESCRIPTION

This export offers basic svc_phone provisioning for PortaOne.

During insert, this will add customers to portaone if they do not yet exist,
using the customer prefix + custnum as the customer name.  An account will
be created for the service and assigned to the customer, using account prefix
+ svcnum as the account id.  During replace, the customer info will be updated
if it already exists in the system.

This module also provides generic methods for working through the L</PortaOne API>.

=cut

use vars qw( %info );

tie my %options, 'Tie::IxHash',
  'username'         => { label => 'User Name',
                          default => '' },
  'password'         => { label => 'Password',
                          default => '' },
  'port'             => { label => 'Port',
                          default => 443 },
  'account_prefix'   => { label => 'Account ID Prefix',
                          default => 'FREESIDE_CUST' },
  'customer_prefix'  => { label => 'Customer Name Prefix',
                          default => 'FREESIDE_SVC' },
  'debug'            => { type => 'checkbox',
                          label => 'Enable debug warnings' },
;

%info = (
  'svc'             => 'svc_phone',
  'desc'            => 'Export customer and service/account to PortaOne',
  'options'         => \%options,
  'notes'           => <<'END',
During insert, this will add customers to portaone if they do not yet exist,
using the customer prefix + custnum as the customer name.  An account will
be created for the service and assigned to the customer, using account prefix
+ svcnum as the account id.  During replace, the customer info will be updated
if it already exists in the system.
END
);

sub _export_insert {
  my ($self, $svc_phone) = @_;

  # load needed info from our end
  my $cust_main = $svc_phone->cust_main;
  return "Could not load service customer" unless $cust_main;
  my $conf = new FS::Conf;

  # initialize api session
  $self->api_login;
  return $self->api_error if $self->api_error;

  # load DID, abort if it is already assigned
#  my $number_info = $self->api_call('DID','get_number_info',{
#    'number' => $svc_phone->countrycode . $svc_phone->phonenum
#  },'number_info');
#  return $self->api_error if $self->api_error;
#  return "Number is already assigned" if $number_info->{'i_account'};

  # reserve DID

  # check if customer already exists
  my $customer_info = $self->api_call('Customer','get_customer_info',{
    'name' => $self->option('customer_prefix') . $cust_main->custnum,
  },'customer_info');
  my $i_customer = $customer_info ? $customer_info->{'i_customer'} : undef;

  # insert customer (using name => custnum) if customer with that name/custnum doesn't exist
  #   has the possibility of creating duplicates if customer was previously hand-entered,
  #   could check if customer has existing services on our end, load customer from one of those
  #   but...not right now
  unless ($i_customer) {
    $i_customer = $self->api_call('Customer','add_customer',{
      'customer_info' => {
        'name' => $self->option('customer_prefix') . $cust_main->custnum,
        'iso_4217' => ($conf->config('currency') || 'USD'),
      }
    },'i_customer');
    return $self->api_error if $self->api_error;
    return "Error creating customer" unless $i_customer;
  }

  # check if account already exists
  my $account_info = $self->api_call('Account','get_account_info',{
    'id' => $self->option('account_prefix') . $svc_phone->svcnum,
  },'account_info');

  my $i_account;
  if ($account_info) {
    # there shouldn't be any time account already exists on insert,
    # but if custnum & svcnum match, should be safe to run with it
    return "Account " . $svc_phone->svcnum . " already exists"
      unless $account_info->{'i_customer'} eq $i_customer;
    $i_account = $account_info->{'i_account'};
  } else {
    # normal case--insert account for this service
    $i_account = $self->api_call('Account','add_account',{
      'account_info' => {
        'id' => $self->option('account_prefix') . $svc_phone->svcnum,
        'i_customer' => $i_customer,
        'iso_4217' => ($conf->config('currency') || 'USD'),
      }
    },'i_account');
    return $self->api_error if $self->api_error;
  }
  return "Error creating account" unless $i_account;

  # assign DID to account

  # update customer, including name
  $self->api_update_customer($i_customer,$cust_main);
  return $self->api_error if $self->api_error;

  # end api session
  return $self->api_logout;
}

sub _export_replace {
  my ($self, $svc_phone, $svc_phone_old) = @_;

  # load needed info from our end
  my $cust_main = $svc_phone->cust_main;
  return "Could not load service customer" unless $cust_main;
  my $conf = new FS::Conf;

  # initialize api session
  $self->api_login;
  return $self->api_error if $self->api_error;

  # check for existing customer
  #   should be loading this from DID...
  my $customer_info = $self->api_call('Customer','get_customer_info',{
    'name' => $cust_main->custnum,
  },'customer_info');
  my $i_customer = $customer_info ? $customer_info->{'i_customer'} : undef;

  return "Customer not found in portaone" unless $i_customer;

  # if did changed
  #   make sure new did is available, reserve
  #   release old did from account
  #   assign new did to account

  # update customer info
  $self->api_update_customer($i_customer,$cust_main);
  return $self->api_error if $self->api_error;

  # end api session
  return $self->api_logout();
}

sub _export_delete {
  my ($self, $svc_phone) = @_;
  return '';
}

sub _export_suspend {
  my ($self, $svc_phone) = @_;
  return '';
}

sub _export_unsuspend {
  my ($self, $svc_phone) = @_;
  return '';
}

=head1 PortaOne API

These methods allow access to the PortaOne API using the credentials
set in the export options.

	$export->api_login;
	die $export->api_error if $export->api_error;

	my $customer_info = $export->api_call('Customer','get_customer_info',{
      'name' => $export->option('customer_prefix') . $cust_main->custnum,
    },'customer_info');
	die $export->api_error if $export->api_error;

	$export->api_logout;
	die $export->api_error if $export->api_error;

=cut

=head2 api_call

Accepts I<$service>, I<$method>, I<$params> hashref and optional
I<$returnfield>.  Places an api call to the specified service
and method with the specified params.  Returns the decoded json
object returned by the api call.  If I<$returnfield> is specified,
returns only that field of the decoded object, and errors out if
that field does not exist.  Returns empty on failure;  retrieve
error messages using L</api_error>.

Must run L</api_login> first.

=cut

sub api_call {
  my ($self,$service,$method,$params,$returnfield) = @_;
  $self->{'__portaone_error'} = '';
  my $auth_info = $self->{'__portaone_auth_info'};
  my %auth_info = $auth_info ? ('auth_info' => encode_json($auth_info)) : ();
  $params ||= {};
  print "Calling $service/$method\n" if $self->option('debug');
  my ( $page, $response, %reply_headers ) = https_post(
    'host'    => $self->machine,
    'port'    => $self->option('port'),
    'path'    => '/rest/'.$service.'/'.$method.'/',
    'args'    => [ %auth_info, 'params' => encode_json($params) ],
  );
  if (($response eq '200 OK') || ($response =~ /^500/)) {
    my $result;
    eval { $result = decode_json($page) };
    unless ($result) {
      $self->{'__portaone_error'} = "Error decoding json: $@";
      return;
    }
    if ($response eq '200 OK') {
      return $result unless $returnfield;
      unless (exists $result->{$returnfield}) {
        $self->{'__portaone_error'} = "Field $returnfield not returned during $service/$method";
        return;
      }
      return $result->{$returnfield};
    }
    if ($result->{'faultcode'}) {
      $self->{'__portaone_error'} = 
        "Server returned error during $service/$method: ".$result->{'faultstring'};
      return;
    }
  }
  $self->{'__portaone_error'} = 
    "Bad response from server during $service/$method: $response";
  return;
}

=head2 api_error

Returns the error string set by L</PortaOne API> methods,
or a blank string if most recent call produced no errors.

=cut

sub api_error {
  my $self = shift;
  return $self->{'__portaone_error'} || '';
}

=head2 api_login

Initializes an api session using the credentials for this export.
Always returns empty.  Retrieve error messages using L</api_error>.

=cut

sub api_login {
  my $self = shift;
  $self->{'__portaone_auth_info'} = undef;  # needs to be declared undef for api_call
  my $result = $self->api_call('Session','login',{
    'login'    => $self->option('username'),
    'password' => $self->option('password'),
  });
  return unless $result;
  $self->{'__portaone_auth_info'} = $result;
  return;
}

=head2 api_logout

Ends the current api session established by L</api_login>.

For convenience, returns L</api_error>.

=cut

sub api_logout {
  my $self = shift;
  $self->api_call('Session','logout',$self->{'__portaone_auth_info'});
  return $self->api_error;
}

=head2 api_update_customer

Accepts I<$i_customer> and I<$cust_main>.  Updates the customer
specified by I<$i_customer> with the current values of I<$cust_main>.
Always returns empty.  Retrieve error messages using L</api_error>.

=cut

sub api_update_customer {
  my ($self,$i_customer,$cust_main) = @_;
  my $location = $cust_main->bill_location;
  unless ($location) {
    $self->{'__portaone_error'} = "Could not load customer location";
    return;
  }
  my $updated_customer = $self->api_call('Customer','update_customer',{
    'i_customer' => $i_customer,
    'companyname' => $cust_main->company,
    'firstname' => $cust_main->first,
    'lastname' => $cust_main->last,
    'baddr1' => $location->address1,
    'baddr2' => $location->address2,
    'city' => $location->city,
    'state' => $location->state,
    'zip' => $location->zip,
    'country' => $location->country,
    # could also add contact phones & email here
  },'i_customer');
  $self->{'__portaone_error'} = "Customer updated, but custnum mismatch detected"
    unless $updated_customer eq $i_customer;
  return;
}

=head1 SEE ALSO

L<FS::part_export>

=head1 AUTHOR

Jonathan Prykop 
jonathan@freeside.biz

=cut

1;


