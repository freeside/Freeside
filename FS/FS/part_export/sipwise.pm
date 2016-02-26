package FS::part_export::sipwise;

use base qw( FS::part_export );
use strict;

use FS::Record qw(qsearch qsearchs dbh);
use Tie::IxHash;
use LWP::UserAgent;
use URI;
use Cpanel::JSON::XS;
use HTTP::Request::Common qw(GET POST PUT DELETE);
use FS::Misc::DateTime qw(parse_datetime);
use DateTime;
use Number::Phone;
use Try::Tiny;

our $me = '[sipwise]';
our $DEBUG = 2;

tie my %options, 'Tie::IxHash',
  'port'            => { label => 'Port' },
  'username'        => { label => 'API username', },
  'password'        => { label => 'API password', },
  'debug'           => { label => 'Enable debugging', type => 'checkbox', value => 1 },
  'billing_profile' => {
    label             => 'Billing profile',
    default           => 'default', # that's what it's called
  },
  'reseller_id'     => { label => 'Reseller ID' },
  'ssl_no_verify'   => { label => 'Skip SSL certificate validation',
                         type  => 'checkbox',
                       },
;

tie my %roles, 'Tie::IxHash',
  'subscriber'    => {  label     => 'Subscriber',
                        svcdb     => 'svc_acct',
                        multiple  => 1,
                     },
  'did'           => {  label     => 'DID',
                        svcdb     => 'svc_phone',
                        multiple  => 1,
                     },
;

our %info = (
  'svc'      => [qw( svc_acct svc_phone )],
  'desc'     => 'Provision to a Sipwise sip:provider server',
  'options'  => \%options,
  'roles'    => \%roles,
  'notes'    => <<'END'
<P>Export to a <b>sip:provider</b> server.</P>
<P>This requires two service definitions to be configured on the same package:
  <OL>
    <LI>An account service for a SIP client account ("subscriber"). The
    <i>username</i> will be the SIP username. The <i>domsvc</i> should point
    to a domain service to use as the SIP domain name.</LI>
    <LI>A phone service for a DID. The <i>phonenum</i> here will be a PSTN
    number. The <i>forward_svcnum</i> field should be set to the account that
    will receive calls at this number.
  </OL>
</P>
<P>Export options:
</P>
END
);

sub export_insert {
  my($self, $svc_x) = (shift, shift);

  my $error;
  my $role = $self->svc_role($svc_x);
  if ( $role eq 'subscriber' ) {

    try { $self->insert_subscriber($svc_x) }
    catch { $error = $_ };

  } elsif ( $role eq 'did' ) {

    try { $self->export_did($svc_x) }
    catch { $error = $_ };

  }
  return "$me $error" if $error;
  '';
}

sub export_replace {
  my ($self, $svc_new, $svc_old) = @_;
  my $role = $self->svc_role($svc_new);

  my $error;
  if ( $role eq 'subscriber' ) {

    try { $self->replace_subscriber($svc_new, $svc_old) }
    catch { $error = $_ };

  } elsif ( $role eq 'did' ) {

    try { $self->export_did($svc_new, $svc_old) }
    catch { $error = $_ };

  }
  return "$me $error" if $error;
  '';
}

sub export_delete {
  my ($self, $svc_x) = (shift, shift);
  my $role = $self->svc_role($svc_x);
  my $error;

  if ( $role eq 'subscriber' ) {

    # no need to remove DIDs from it, just drop the subscriber record
    try { $self->delete_subscriber($svc_x) }
    catch { $error = $_ };

  } elsif ( $role eq 'did' ) {

    try { $self->export_did($svc_x) }
    catch { $error = $_ };

  }
  return "$me $error" if $error;
  '';
}

# XXX NOT DONE YET
sub export_suspend {
  my $self = shift;
  my $svc_x = shift;
  my $role = $self->svc_role($svc_x);
  return if $role ne 'subacct'; # can't suspend DIDs directly

  my $error = $self->replace_subacct($svc_x, $svc_x); # will disable it
  return "$me $error" if $error;
  '';
}

sub export_unsuspend {
  my $self = shift;
  my $svc_x = shift;
  my $role = $self->svc_role($svc_x);
  return if $role ne 'subacct'; # can't suspend DIDs directly

  $svc_x->set('unsuspended', 1); # hack to tell replace_subacct to do it
  my $error = $self->replace_subacct($svc_x, $svc_x); #same
  return "$me $error" if $error;
  '';
}

#############
# CUSTOMERS #
#############

=item get_customer SERVICE

Returns the Sipwise customer record that should belong to SERVICE. This is
based on the pkgnum field.

=cut

sub get_customer {
  my $self = shift;
  my $svc = shift;
  my $pkgnum = $svc->cust_svc->pkgnum;
  my $custid = "cust_pkg#$pkgnum";

  my @cust = $self->api_query('customers', [ external_id => $custid ]);
  warn "$me multiple customers for external_id $custid.\n" if scalar(@cust) > 1;
  $cust[0];
}

sub find_or_create_customer {
  my $self = shift;
  my $svc = shift;
  my $cust = $self->get_customer($svc);
  return $cust if $cust;

  my $cust_pkg = $svc->cust_svc->cust_pkg;
  my $cust_main = $cust_pkg->cust_main;
  my $cust_location = $cust_pkg->cust_location;
  my ($email) = $cust_main->invoicing_list_emailonly;
  my $custid = 'cust_pkg#' . $cust_pkg->pkgnum;

  # find the billing profile
  my ($billing_profile) = $self->api_query('billingprofiles',
    [
      'handle'        => $self->option('billing_profile'),
      'reseller_id'   => $self->option('reseller_id'),
    ]
  );
  if (!$billing_profile) {
    die "can't find billing profile '". $self->option('billing_profile') . "'\n";
  }
  my $bpid = $billing_profile->{id};

  # contacts unfortunately have no searchable external_id or other field
  # like that, so we can't go location -> package -> service
  my $contact = $self->api_create('customercontacts',
    {
      'city'          => $cust_location->city,
      'company'       => $cust_main->company,
      'country'       => $cust_location->country,
      'email'         => $email,
      'faxnumber'     => $cust_main->fax,
      'firstname'     => $cust_main->first,
      'lastname'      => $cust_main->last,
      'mobilenumber'  => $cust_main->mobile,
      'phonenumber'   => ($cust_main->daytime || $cust_main->night),
      'postcode'      => $cust_location->zip,
      'reseller_id'   => $self->option('reseller_id'),
      'street'        => $cust_location->address1,
    }
  );

  $cust = $self->api_create('customers',
    {
      'status'      => 'active',
      'type'        => 'sipaccount',
      'contact_id'  => $contact->{id},
      'external_id' => $custid,
      'billing_profile_id' => $bpid,
    }
  );

  $cust;
}

###########
# DOMAINS #
###########

=item find_or_create_domain DOMAIN

Returns the record for the domain object named DOMAIN. If necessary, will
create it first.

=cut

sub find_or_create_domain {
  my $self = shift;
  my $domainname = shift;
  my ($domain) = $self->api_query('domains', [ 'domain' => $domainname ]);
  return $domain if $domain;

  $self->api_create('domains',
    {
      'domain'        => $domainname,
      'reseller_id'   => $self->option('reseller_id'),
    }
  );
}

########
# DIDS #
########

=item acct_for_did SVC_PHONE

Returns the subscriber svc_acct linked to SVC_PHONE.

=cut

sub acct_for_did {
  my $self = shift;
  my $svc_phone = shift;
  my $svcnum = $svc_phone->forward_svcnum or return;
  my $svc_acct = FS::svc_acct->by_key($svcnum) or return;
  $self->svc_role($svc_acct) eq 'subscriber' or return;
  $svc_acct;
}

=item export_did NEW, OLD

Refreshes the subscriber information for the service the DID was linked to
previously, and the one it's linked to now.

=cut

sub export_did {
  my $self = shift;
  my ($new, $old) = @_;
  if ( $old and $new->forward_svcnum ne $old->forward_svcnum ) {
    $self->replace_subscriber( $self->acct_for_did($old) );
  }
  $self->replace_subscriber( $self->acct_for_did($new) );
}

###############
# SUBSCRIBERS #
###############

=item get_subscriber SVC

Gets the subscriber record for SVC, if there is one.

=cut

sub get_subscriber {
  my $self = shift;
  my $svc = shift;

  my $svcnum = $svc->svcnum;
  my $svcid = "svc#$svcnum";

  my $pkgnum = $svc->cust_svc->pkgnum;
  my $custid = "cust_pkg#$pkgnum";

  my @subscribers = grep { $_->{external_id} eq $svcid }
    $self->api_query('subscribers',
      [ 'customer_external_id' => $custid ]
    );
  warn "$me multiple subscribers for external_id $svcid.\n"
    if scalar(@subscribers) > 1;

  $subscribers[0];
}

# internal method: find DIDs that forward to this service

sub did_numbers_for_svc {
  my $self = shift;
  my $svc = shift;
  my @numbers;
  my @dids = qsearch({
      'table'     => 'svc_phone',
      'hashref'   => { 'forward_svcnum' => $svc->svcnum }
  });
  foreach my $did (@dids) {
    # only include them if they're interesting to this export
    if ( $self->svc_role($did) eq 'did' ) {
      my $phonenum;
      if ($did->countrycode) {
        $phonenum = Number::Phone->new('+' . $did->countrycode . $did->phonenum);
      } else {
        # the long way
        my $country = $did->cust_svc->cust_pkg->cust_location->country;
        $phonenum = Number::Phone->new($country, $did->phonenum);
      }
      if (!$phonenum) {
        die "Can't process phonenum ".$did->countrycode . $did->phonenum . "\n";
      }
      push @numbers,
        { 'cc' => $phonenum->country_code,
          'ac' => $phonenum->areacode,
          'sn' => $phonenum->subscriber
        };
    }
  }
  @numbers;
}

sub insert_subscriber {
  my $self = shift;
  my $svc = shift;

  my $cust = $self->find_or_create_customer($svc);
  my $svcid = "svc#" . $svc->svcnum;
  my $status = $svc->cust_svc->cust_pkg->susp ? 'locked' : 'active';
  my $domain = $self->find_or_create_domain($svc->domain);

  my @numbers = $self->did_numbers_for_svc($svc);
  my $first_number = shift @numbers;

  my $subscriber = $self->api_create('subscribers',
    {
      'alias_numbers'   => \@numbers,
      'customer_id'     => $cust->{id},
      'display_name'    => $svc->finger,
      'domain_id'       => $domain->{id},
      'external_id'     => $svcid,
      'password'        => $svc->_password,
      'primary_number'  => $first_number,
      'status'          => $status,
      'username'        => $svc->username,
    }
  );
}

sub replace_subscriber {
  my $self = shift;
  my $svc = shift;
  my $old = shift || $svc->replace_old;
  my $svcid = "svc#" . $svc->svcnum;

  my $cust = $self->find_or_create_customer($svc);
  my $status = $svc->cust_svc->cust_pkg->susp ? 'locked' : 'active';
  my $domain = $self->find_or_create_domain($svc->domain);
  
  my @numbers = $self->did_numbers_for_svc($svc);
  my $first_number = shift @numbers;

  my $subscriber = $self->get_subscriber($svc);

  if ( $subscriber ) {
    my $id = $subscriber->{id};
    if ( $svc->username ne $old->username ) {
      # have to delete and recreate
      $self->api_delete("subscribers/$id");
      $self->insert_subscriber($svc);
    } else {
      $self->api_update("subscribers/$id",
        {
          'alias_numbers'   => \@numbers,
          'customer_id'     => $cust->{id},
          'display_name'    => $svc->finger,
          'domain_id'       => $domain->{id},
          'email'           => $svc->email,
          'external_id'     => $svcid,
          'password'        => $svc->_password,
          'primary_number'  => $first_number,
          'status'          => $status,
          'username'        => $svc->username,
        }
      );
    }
  } else {
    warn "$me subscriber not found for $svcid; creating new\n";
    $self->insert_subscriber($svc);
  }
}

sub delete_subscriber {
  my $self = shift;
  my $svc = shift;
  my $svcid = "svc#" . $svc->svcnum;
  my $pkgnum = $svc->cust_svc->pkgnum;
  my $custid = "cust_pkg#$pkgnum";

  my $subscriber = $self->get_subscriber($svc);

  if ( $subscriber ) {
    my $id = $subscriber->{id};
    $self->api_delete("subscribers/$id");
  } else {
    warn "$me subscriber not found for $svcid (would be deleted)\n";
  }

  my (@other_subs) = $self->api_query('subscribers',
    [ 'customer_external_id' => $custid ]
  );
  if (! @other_subs) {
    # then it's safe to remove the customer
    my ($cust) = $self->api_query('customers', [ 'external_id' => $custid ]);
    if (!$cust) {
      warn "$me customer not found for $custid\n";
      return;
    }
    my $id = $cust->{id};
    my $contact_id = $cust->{contact_id};
    if ( $cust->{'status'} ne 'terminated' ) {
      # can't delete customers, have to cancel them
      $cust->{'status'} = 'terminated';
      $cust->{'external_id'} = ""; # dissociate it from this pkgnum
      $cust->{'contact_id'} = 1; # set to the system default contact
      $self->api_update("customers/$id", $cust);
    }
    # can and should delete contacts though
    $self->api_delete("customercontacts/$contact_id");
  }
}

##############
# API ACCESS #
##############

=item api_query RESOURCE, CONTENT

Makes a GET request to RESOURCE, the name of a resource type (like
'customers'), with query parameters in CONTENT, unpacks the embedded search
results, and returns them as a list.

Sipwise ignores invalid query parameters rather than throwing an error, so if
the parameters are misspelled or make no sense for this type of query, it will
probably return all of the objects.

=cut

sub api_query {
  my $self = shift;
  my ($resource, $content) = @_;
  if ( ref $content eq 'HASH' ) {
    $content = [ %$content ];
  }
  my $result = $self->api_request('GET', $resource, $content);
  my @records;
  # depaginate
  while ( my $things = $result->{_embedded}{"ngcp:$resource"} ) {
    if ( ref($things) eq 'ARRAY' ) {
      push @records, @$things;
    } else {
      push @records, $things;
    }
    if ( my $linknext = $result->{_links}{next} ) {
      warn "$me continued at $linknext\n" if $DEBUG;
      $result = $self->api_request('GET', $linknext);
    } else {
      last;
    }
  }
  return @records;
}

=item api_create RESOURCE, CONTENT

Makes a POST request to RESOURCE, the name of a resource type (like
'customers'), to create a new object of that type. CONTENT must be a hashref of
the object's fields.

On success, will then fetch and return the newly created object. On failure,
will throw the "message" parameter from the request as an exception.

=cut

sub api_create {
  my $self = shift;
  my ($resource, $content) = @_;
  my $result = $self->api_request('POST', $resource, $content);
  if ( $result->{location} ) {
    return $self->api_request('GET', $result->{location});
  } else {
    die $result->{message} . "\n";
  }
}

=item api_update ENDPOINT, CONTENT

Makes a PUT request to ENDPOINT, the name of a specific record (like
'customers/11'), to replace it with the data in CONTENT (a hashref of the
object's fields). On failure, will throw an exception. On success,
returns nothing.

=cut

sub api_update {
  my $self = shift;
  my ($endpoint, $content) = @_;
  my $result = $self->api_request('PUT', $endpoint, $content);
  if ( $result->{message} ) {
    die $result->{message} . "\n";
  }
  return;
}

=item api_delete ENDPOINT

Makes a DELETE request to ENDPOINT. On failure, will throw an exception.

=cut

sub api_delete {
  my $self = shift;
  my $endpoint = shift;
  my $result = $self->api_request('DELETE', $endpoint);
  if ( $result->{code} and $result->{code} eq '404' ) {
    # special case: this is harmless. we tried to delete something and it
    # was already gone.
    warn "$me api_delete $endpoint: does not exist\n";
    return;
  } elsif ( $result->{message} ) {
    die $result->{message} . "\n";
  }
  return;
}

=item api_request METHOD, ENDPOINT, CONTENT

Makes a REST request with HTTP method METHOD, to path ENDPOINT, with content
CONTENT. If METHOD is GET, the content can be an arrayref or hashref to append
as the query argument. If it's POST or PUT, the content will be JSON-serialized
and sent as the request body. If it's DELETE, content will be ignored.

=cut

sub api_request {
  my $self = shift;
  my ($method, $endpoint, $content) = @_;
  $DEBUG ||= 1 if $self->option('debug');
  my $url;
  if ($endpoint =~ /^http/) {
    # allow directly using URLs returned from the API
    $url = $endpoint;
  } else {
    $endpoint =~ s[/api/][]; # allow using paths returned in Location headers
    $url = 'https://' . $self->host . '/api/' . $endpoint;
    $url .= '/' unless $url =~ m[/$];
  }
  my $request;
  if ( lc($method) eq 'get' ) {
    $url = URI->new($url);
    $url->query_form($content);
    $request = GET($url,
      'Accept'        => 'application/json'
    );
  } elsif ( lc($method) eq 'post' ) {
    $request = POST($url,
      'Accept'        => 'application/json',
      'Content'       => encode_json($content),
      'Content-Type'  => 'application/json',
    );
  } elsif ( lc($method) eq 'put' ) {
    $request = PUT($url,
      'Accept'        => 'application/json',
      'Content'       => encode_json($content),
      'Content-Type'  => 'application/json',
    );
  } elsif ( lc($method) eq 'delete' ) {
    $request = DELETE($url);
  }

  warn "$me $method $endpoint\n" if $DEBUG;
  warn $request->as_string ."\n" if $DEBUG > 1;
  my $response = $self->ua->request($request);
  warn "$me received\n" . $response->as_string ."\n" if $DEBUG > 1;

  my $decoded_response = {};
  if ( $response->content ) {
    local $@;
    $decoded_response = eval { decode_json($response->content) };
    if ( $@ ) {
      # then it can't be parsed; probably a low-level error of some kind.
      warn "$me Parse error.\n".$response->content."\n\n";
      die "$me Parse error:".$response->content . "\n";
    }
  }
  if ( $response->header('Location') ) {
    $decoded_response->{location} = $response->header('Location');
  }
  return $decoded_response;
}

# a little false laziness with aradial.pm
sub host {
  my $self = shift;
  my $port = $self->option('port') || 1443;
  $self->machine . ":$port";
}

sub ua {
  my $self = shift;
  $self->{_ua} ||= do {
    my @opt;
    if ( $self->option('ssl_no_verify') ) {
      push @opt, ssl_opts => { verify_hostname => 0 };
    }
    my $ua = LWP::UserAgent->new(@opt);
    $ua->credentials(
      $self->host,
      'api_admin_http',
      $self->option('username'),
      $self->option('password')
    );
    $ua;
  }
}


1;
