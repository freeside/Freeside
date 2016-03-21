package FS::part_export::portaone;

use strict;

use base qw( FS::part_export );

use Date::Format 'time2str';
use JSON::XS;
use Net::HTTPS::Any qw(https_post);

use FS::Conf;

=pod

=head1 NAME

FS::part_export::portaone

=head1 SYNOPSIS

PortaOne integration for Freeside

=head1 DESCRIPTION

This export offers basic svc_phone provisioning for PortaOne.

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
  'customer_name'    => { label => 'Customer Name',
                          default => 'FREESIDE CUST $custnum' },
  'account_id'       => { label => 'Account ID',
                          default => 'FREESIDE SVC $svcnum' },
  'product_id'       => { label => 'Account Product ID' },
  'debug'            => { type => 'checkbox',
                          label => 'Enable debug warnings' },
;

%info = (
  'svc'             => 'svc_phone',
  'desc'            => 'Export customer and service/account to PortaOne',
  'options'         => \%options,
  'notes'           => <<'END',
During insert, this will add customers to portaone if they do not yet exist,
using the "Customer Name" option with substitutions from the customer record 
in freeside.  If options "Account ID" and "Account Product ID" are also specified,
an account will be created for the service and assigned to the customer, using 
substitutions from the phone service record in freeside for the Account ID.

During replace, if a matching account id for the old service can be found,
the existing customer and account will be updated.  Otherwise, if a matching 
customer name is found, the info for that customer will be updated.  
Otherwise, nothing will be updated during replace.

Use caution to avoid name/id conflicts when introducing this export to a portaone 
system with existing customers/accounts.
END
);

### NOTE:  If we provision DIDs, conflicts with existing data and changes
### to the name/id scheme will be non-issues, as we can load DID by number 
### and then load account/customer from there, but provisioning DIDs has
### not yet been implemented....

sub _export_insert {
  my ($self, $svc_phone) = @_;

  # load needed info from our end
  my $cust_main = $svc_phone->cust_main;
  return "Could not load service customer" unless $cust_main;
  my $conf = new FS::Conf;

  # make sure customer name is configured
  my $customer_name = $self->portaone_customer_name($cust_main);
  return "No customer name configured, nothing to export"
    unless $customer_name;

  # initialize api session
  $self->api_login;
  return $self->api_error if $self->api_error;

  # check if customer already exists
  my $customer_info = $self->api_call('Customer','get_customer_info',{
    'name' => $customer_name,
  },'customer_info');
  my $i_customer = $customer_info ? $customer_info->{'i_customer'} : undef;

  # insert customer (using name => custnum) if customer with that name/custnum doesn't exist
  #   has the possibility of creating duplicates if customer was previously hand-entered,
  #   could check if customer has existing services on our end, load customer from one of those
  #   but...not right now
  unless ($i_customer) {
    $i_customer = $self->api_call('Customer','add_customer',{
      'customer_info' => {
        'name' => $customer_name,
        'iso_4217' => ($conf->config('currency') || 'USD'),
      }
    },'i_customer');
    return $self->api_error_logout if $self->api_error;
    unless ($i_customer) {
      $self->api_logout;
      return "Error creating customer";
    }
  }

  # export account if account id is configured
  my $account_id = $self->portaone_account_id($svc_phone);
  my $product_id = $self->option('product_id');
  if ($account_id && $product_id) {
    # check if account already exists
    my $account_info = $self->api_call('Account','get_account_info',{
      'id' => $account_id,
    },'account_info');

    my $i_account;
    if ($account_info) {
      # there shouldn't be any time account already exists on insert,
      # but if custnum matches, should be safe to run with it
      unless ($account_info->{'i_customer'} eq $i_customer) {
        $self->api_logout;
        return "Account $account_id already exists";
      }
      $i_account = $account_info->{'i_account'};
    } else {
      # normal case--insert account for this service
      $i_account = $self->api_call('Account','add_account',{
        'account_info' => {
          'id' => $account_id,
          'i_customer' => $i_customer,
          'iso_4217' => ($conf->config('currency') || 'USD'),
          'i_product' => $product_id,
          'activation_date' => time2str("%Y-%m-%d %H:%M:%S",time),
          'billing_model'   => 1, # '1' for credit, '-1' for debit, could make this an export option
        }
      },'i_account');
      return $self->api_error_logout if $self->api_error;
    }
    unless ($i_account) {
      $self->api_logout;
      return "Error creating account";
    }
  }

  # update customer, including name
  $self->api_update_customer($i_customer,$cust_main);
  return $self->api_error_logout if $self->api_error;

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

  # if we ever provision DIDs, we should load from DID rather than account

  # check for existing account
  my $account_id = $self->portaone_account_id($svc_phone_old);
  my $account_info = $self->api_call('Account','get_account_info',{
    'id' => $account_id,
  },'account_info');
  my $i_account = $account_info ? $account_info->{'i_account'} : undef;

  # if account exists, use account customer
  my $i_customer;
  if ($account_info) {
    $i_account  = $account_info->{'i_account'};
    $i_customer = $account_info->{'i_customer'};
    # if nothing changed, no need to update account
    $i_account = undef
      if ($account_info->{'i_product'} eq $self->option('product_id'))
         && ($account_id eq $self->portaone_account_id($svc_phone));
  # otherwise, check for existing customer
  } else {
    my $customer_name = $self->portaone_customer_name($cust_main);
    my $customer_info = $self->api_call('Customer','get_customer_info',{
      'name' => $customer_name,
    },'customer_info');
    $i_customer = $customer_info ? $customer_info->{'i_customer'} : undef;
  }

  unless ($i_customer) {
    $self->api_logout;
    return "Neither customer nor account found in portaone";
  }

  # update customer info
  $self->api_update_customer($i_customer,$cust_main) if $i_customer;
  return $self->api_error_logout if $self->api_error;

  # update account info
  $self->api_update_account($i_account,$svc_phone) if $i_account;
  return $self->api_error_logout if $self->api_error;

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
      'name' => $export->portaone_customer_name($cust_main),
    },'customer_info');
	die $export->api_error_logout if $export->api_error;

	return $export->api_logout;

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

=head2 api_error_logout

Attempts L</api_logout>, but returns L</api_error> message from
before logout was attempted.  Useful for logging out
properly after an error.

=cut

sub api_error_logout {
  my $self = shift;
  my $error = $self->api_error;
  $self->api_logout;
  return $error;
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

=head2 api_update_account

Accepts I<$i_account> and I<$svc_phone>.  Updates the account
specified by I<$i_account> with the current values of I<$svc_phone>
(currently only updates account_id.)
Always returns empty.  Retrieve error messages using L</api_error>.

=cut

sub api_update_account {
  my ($self,$i_account,$svc_phone) = @_;
  my $newid = $self->portaone_account_id($svc_phone);
  unless ($newid) {
    $self->{'__portaone_error'} = "Error loading account id during update_account";
    return;
  }
  my $updated_account = $self->api_call('Account','update_account',{
    'account_info' => {
      'i_account' => $i_account,
      'id' => $newid,
      'i_product' => $self->option('product_id'),
    },
  },'i_account');
  return if $self->api_error;
  $self->{'__portaone_error'} = "Account updated, but account id mismatch detected"
    unless $updated_account eq $i_account; # should never happen
  return;
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
  my $newname = $self->portaone_customer_name($cust_main);
  unless ($newname) {
    $self->{'__portaone_error'} = "Error loading customer name during update_customer";
    return;
  }
  my $updated_customer = $self->api_call('Customer','update_customer',{
    'customer_info' => {
      'i_customer' => $i_customer,
      'name' => $newname,
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
    },
  },'i_customer');
  return if $self->api_error;
  $self->{'__portaone_error'} = "Customer updated, but custnum mismatch detected"
    unless $updated_customer eq $i_customer; # should never happen
  return;
}

sub _substitute {
  my ($self, $string, @objects) = @_;
  return '' unless $string;
  foreach my $object (@objects) {
    next unless $object;
    foreach my $field ($object->fields) {
      next unless $field;
      my $value = $object->get($field);
      $string =~ s/\$$field/$value/g;
    }
  }
  # strip leading/trailing whitespace
  $string =~ s/^\s//g;
  $string =~ s/\s$//g;
  return $string;
}

=head2 portaone_customer_name

Accepts I<$cust_main> and returns customer name with substitutions.

=cut

sub portaone_customer_name {
  my ($self, $cust_main) = @_;
  $self->_substitute($self->option('customer_name'),$cust_main);
}

=head2 portaone_account_id

Accepts I<$svc_phone> and returns account id with substitutions.

=cut

sub portaone_account_id {
  my ($self, $svc_phone) = @_;
  $self->_substitute($self->option('account_id'),$svc_phone);
}

=head1 SEE ALSO

L<FS::part_export>

=head1 AUTHOR

Jonathan Prykop 
jonathan@freeside.biz

=cut

1;


