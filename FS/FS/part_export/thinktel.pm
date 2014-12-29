package FS::part_export::thinktel;

use base qw( FS::part_export );
use strict;

use Tie::IxHash;
use URI::Escape;
use LWP::UserAgent;
use URI::Escape;
use JSON;

use FS::Record qw( qsearch qsearchs );

our $me = '[Thinktel VoIP]';
our $DEBUG = 1;
our $base_url = 'https://api.thinktel.ca/rest.svc/';

# cache cities and provinces
our %CACHE;
our $cache_timeout = 60; # seconds
our $last_cache_update = 0;

# static data

tie my %locales, 'Tie::IxHash', (
  EnglishUS => 0,
  EnglishUK => 1,
  EnglishCA => 2,
  UserDefined1 => 3,
  UserDefined2 => 4,
  FrenchCA  => 5,
  SpanishLatinAmerica => 6
);

tie my %options, 'Tie::IxHash',
  'username'        => { label => 'Thinktel username', },
  'password'        => { label => 'Thinktel password', },
  'debug'           => { label => 'Enable debugging', type => 'checkbox', value => 1 },
  'plan_id'         => { label => 'Trunk plan ID' },
  'locale'          => {
    label => 'Locale',
    type => 'select',
    options => [ keys %locales ],
  },
  'proxy'           => {
    label => 'SIP Proxy',
    type => 'select',
    options =>
      [ 'edm.trk.tprm.ca', 'tor.trk.tprm.ca' ],
  },
  'trunktype'       => {
    label => 'SIP Trunk Type',
    type => 'select',
    options => [
      'Avaya CM/SM',
      'Default SIP MG Model',
      'Microsoft Lync Server 2010',
    ],
  },

;

tie my %roles, 'Tie::IxHash',
  'trunk'   => {  label     => 'SIP trunk',
                  svcdb     => 'svc_phone',
               },
  'did'     => {  label     => 'DID',
                  svcdb     => 'svc_phone',
                  multiple  => 1,
               },
  'gateway' => {  label     => 'SIP gateway',
                  svcdb     => 'svc_pbx',
                  multiple  => 1,
               },
;

our %info = (
  'svc'         => [qw( svc_phone svc_pbx)],
  'desc'        =>
    'Provision trunks and DIDs to Thinktel VoIP',
  'options'     => \%options,
  'roles'       => \%roles,
  'no_machine'  => 1,
  'notes'       => <<'END'
<P>Export to Thinktel SIP Trunking service.</P>
<P>This requires three service definitions to be configured:
  <OL>
    <LI>A phone service for the SIP trunk. This should be attached to the 
    export in the "trunk" role. Usually there will be only one of these
    per package. The <I>max_simultaneous</i> field of this service will set 
    the channel limit on the trunk. The <i>sip_password</i> will be used for
    all gateways.</LI>
    <LI>A phone service for a DID. This should be attached in the "did" role.
    DIDs should have no properties other than the number and the E911 
    location.</LI>
    <LI>A PBX service for the customer's SIP gateway (Asterisk, OpenPBX, etc. 
    device). This should be attached in the "gateway" role. The <i>ip_addr</i> 
    field should be set to the static IP address that will receive calls. 
    There may be more than one of these on the trunk.</LI>
  </OL>
  All three services must be within the same package. The "pbxsvc" field of
  phone services will be ignored, as the DIDs do not belong to a specific 
  svc_pbx in a multi-gateway setup.
</P>
END
);

sub check_svc { # check the service for validity
  my($self, $svc_x) = (shift, shift);
  my $role = $self->svc_role($svc_x)
    or return "No export role is assigned to this service type.";
  if ( $role eq 'trunk' ) {
    if (! $svc_x->isa('FS::svc_phone')) {
      return "This is the wrong type of service (should be svc_phone).";
    }
    if (length($svc_x->sip_password) == 0
        or length($svc_x->sip_password) > 14) {
      return "SIP password must be 1 to 14 characters.";
    }
  } elsif ( $role eq 'did' ) {
    # nothing really to check
  } elsif ( $role eq 'gateway' ) {
    if ($svc_x->max_simultaneous == 0) {
      return "The maximum simultaneous calls field must be > 0."
    }
    if (!$svc_x->ip_addr) {
      return "The gateway must have an IP address."
    }
  }

  '';
}

sub export_insert {
  my($self, $svc_x) = (shift, shift);

  my $error = $self->check_svc($svc_x);
  return $error if $error;
  my $role = $self->svc_role($svc_x);
  $self->queue_action("insert_$role", $svc_x->svcnum);
}

sub queue_action {
  my $self = shift;
  my $action = shift; #'action_role' format: 'insert_did', 'delete_trunk', etc.
  my $svcnum = shift;
  my @arg = ($self->exportnum, $svcnum, @_);

  my $job = FS::queue->new({
      job => 'FS::part_export::thinktel::'.$action,
      svcnum => $svcnum,
  });

  $job->insert(@arg);
}

sub insert_did {
  my ($exportnum, $svcnum) = @_;
  my $self = FS::part_export->by_key($exportnum);
  my $svc_x = FS::svc_phone->by_key($svcnum);

  my $phonenum = $svc_x->phonenum;
  my $trunk_svc = $self->svc_with_role($svc_x, 'trunk')
    or return; # non-fatal; just wait for the trunk to be created

  my $trunknum = $trunk_svc->phonenum;

  my $endpoint = "SipTrunks/$trunknum/Dids";
  my $content = [ { Number  => $phonenum } ];

  my $result = $self->api_request('POST', $endpoint, $content);

  # probably can only be one of these
  my $error = join("\n",
    map { $_->{Message} } grep { $_->{Reply} != 1 } @$result
  );

  if ( $error ) {
    warn "$me error provisioning $phonenum to $trunknum: $error\n";
    die "$me $error";
  }

  # now insert the V911 record
  $endpoint = "V911s";
  $content = $self->e911_content($svc_x);

  $result = $self->api_request('POST', $endpoint, $content);
  if ( $result->{Reply} != 1 ) {
    $error = "$me $result->{Message}";
    # then delete the DID to keep things consistent
    warn "$me error configuring e911 for $phonenum: $error\nReverting DID order.\n";
    $endpoint = "SipTrunks/$trunknum/Dids/$phonenum";
    $result = $self->api_request('DELETE', $endpoint);
    if ( $result->{Reply} != 1 ) {
      warn "Failed: $result->{Message}\n";
      die "$error. E911 provisioning failed, but the DID could not be deleted: '" . $result->{Message} . "'. You may need to remove the DID manually.";
    }
    die $error;
  }
}

sub insert_gateway {
  my ($exportnum, $svcnum) = @_;
  my $self = FS::part_export->by_key($exportnum);
  my $svc_x = FS::svc_pbx->by_key($svcnum);

  my $trunk_svc = $self->svc_with_role($svc_x, 'trunk')
    or return;

  my $trunknum = $trunk_svc->phonenum;
  # and $svc_x is a svc_pbx service

  my $endpoint = "SipBindings";
  my $content = {
    ContactIPAddress  => $svc_x->ip_addr,
    ContactPort       => 5060,
    IPMatchRequired   => JSON::true,
    SipDomainName     => $self->option('proxy'),
    SipTrunkType      => $self->option('trunktype'),
    SipUsername       => $trunknum,
    SipPassword       => $trunk_svc->sip_password,
  };
  my $result = $self->api_request('POST', $endpoint, $content);

  if ( $result->{Reply} != 1 ) {
    die "$me ".$result->{Message};
  }

  # store the binding ID in the service
  my $binding_id = $result->{ID};
  warn "$me created SIP binding with ID $binding_id\n" if $DEBUG;
  local $FS::svc_Common::noexport_hack = 1;
  $svc_x->set('uuid', $binding_id);
  my $error = $svc_x->replace;
  if ( $error ) {
    $error = "$me storing the SIP binding ID in the database: $error";
  } else {
    # link the main trunk record to the IP address binding
    $endpoint = "SipTrunks/$trunknum/Lines";
    $content = {
      'Channels'     => $svc_x->max_simultaneous,
      'SipBindingID' => $binding_id,
      'TrunkNumber'  => $trunknum,
    };
    $result = $self->api_request('POST', $endpoint, $content);
    if ( $result->{Reply} != 1 ) {
      $error = "$me attaching binding $binding_id to $trunknum: " .
        $result->{Message};
    }
  }

  if ( $error ) {
    # delete the binding
    $endpoint = "SipBindings/$binding_id";
    $result = $self->api_request('DELETE', $endpoint);
    if ( $result->{Reply} != 1 ) {
      my $addl_error = $result->{Message};
      warn "$error. The SIP binding could not be deleted: '$addl_error'.\n";
    }
    die $error;
  }
}

sub insert_trunk {
  my ($exportnum, $svcnum) = @_;
  my $self = FS::part_export->by_key($exportnum);
  my $svc_x = FS::svc_phone->by_key($svcnum);
  my $phonenum = $svc_x->phonenum;

  my $endpoint = "SipTrunks";
  my $content = {
    Account           => $self->option('username'),
    Enabled           => JSON::true,
    Label             => $svc_x->phone_name_or_cust,
    Locale            => $locales{$self->option('locale')},
    MaxChannels       => $svc_x->max_simultaneous,
    Number            => { Number => $phonenum },
    PlanID            => $self->option('plan_id'),
    ThirdPartyLabel   => $svc_x->svcnum,
  };

  my $result = $self->api_request('POST', $endpoint, $content);
  if ( $result->{Reply} != 1 ) {
    die "$me ".$result->{Message};
  }

  my @gateways = $self->svc_with_role($svc_x, 'gateway');
  my @dids = $self->svc_with_role($svc_x, 'did');
  warn "$me inserting dependent services to trunk #$phonenum\n".
       "gateways: ".@gateways."\nDIDs: ".@dids."\n";

  foreach my $svc_x (@gateways, @dids) {
    $self->export_insert($svc_x); # will generate additional queue jobs
  }
}

sub export_replace {
  my ($self, $svc_new, $svc_old) = @_;

  my $error = $self->check_svc($svc_new);
  return $error if $error;

  my $role = $self->svc_role($svc_new)
    or return "No export role is assigned to this service type.";

  if ( $role eq 'did' and $svc_new->phonenum ne $svc_old->phonenum ) {
    my $pkgnum = $svc_new->cust_svc->pkgnum;
    # not that the UI allows this...
    return $self->queue_action("delete_did", $svc_old->svcnum, 
                               $svc_old->phonenum, $pkgnum)
        || $self->queue_action("insert_did", $svc_new->svcnum);
  }

  my %args;
  if ( $role eq 'trunk' and $svc_new->sip_password ne $svc_old->sip_password ) {
    # then trigger a password change
    %args = (password_change => 1);
  }
    
  $self->queue_action("replace_$role", $svc_new->svcnum, %args);
}

sub replace_trunk {
  my ($exportnum, $svcnum, %args) = @_;
  my $self = FS::part_export->by_key($exportnum);
  my $svc_x = FS::svc_phone->by_key($svcnum);

  my $enabled = JSON::is_bool( $self->cust_svc->cust_pkg->susp == 0 );

  my $phonenum = $svc_x->phonenum;
  my $endpoint = "SipTrunks/$phonenum";
  my $content = {
    Account           => $self->options('username'),
    Enabled           => $enabled,
    Label             => $svc_x->phone_name_or_cust,
    Locale            => $self->option('locale'),
    MaxChannels       => $svc_x->max_simultaneous,
    Number            => $phonenum,
    PlanID            => $self->option('plan_id'),
    ThirdPartyLabel   => $svc_x->svcnum,
  };

  my $result = $self->api_request('PUT', $endpoint, $content);
  if ( $result->{Reply} != 1 ) {
    die "$me ".$result->{Message};
  }

  if ( $args{password_change} ) {
    # then propagate the change to the bindings
    my @bindings = $self->svc_with_role($svc_x->gateway);
    foreach my $svc_pbx (@bindings) {
      my $error = $self->export_replace($svc_pbx);
      die "$me updating password on bindings: $error\n" if $error;
    }
  }
}

sub replace_did {
  # we don't handle phonenum/trunk changes
  my ($exportnum, $svcnum, %args) = @_;
  my $self = FS::part_export->by_key($exportnum);
  my $svc_x = FS::svc_phone->by_key($svcnum);

  my $trunk_svc = $self->svc_with_role($svc_x, 'trunk')
    or return;
  my $phonenum = $svc_x->phonenum;
  my $endpoint = "V911s/$phonenum";
  my $content = $self->e911_content($svc_x);

  my $result = $self->api_request('PUT', $endpoint, $content);
  if ( $result->{Reply} != 1 ) {
    die "$me ".$result->{Message};
  }
}

sub replace_gateway {
  my ($exportnum, $svcnum, %args) = @_;
  my $self = FS::part_export->by_key($exportnum);
  my $svc_x = FS::svc_pbx->by_key($svcnum);

  my $trunk_svc = $self->svc_with_role($svc_x, 'trunk')
    or return;

  my $binding_id = $svc_x->uuid;

  my $trunknum = $trunk_svc->phonenum;

  my $endpoint = "SipBindings/$binding_id";
  # get the canonical name of the binding
  my $result = $self->api_request('GET', $endpoint);
  if ( $result->{Message} ) {
    # then assume the binding is not yet set up
    return $self->export_insert($svc_x);
  }
  my $binding_name = $result->{Name};
 
  my $content = {
    ContactIPAddress  => $svc_x->ip_addr,
    ContactPort       => 5060,
    ID                => $binding_id,
    IPMatchRequired   => JSON::true,
    Name              => $binding_name,
    SipDomainName     => $self->option('proxy'),
    SipTrunkType      => $self->option('trunktype'),
    SipUsername       => $trunknum,
    SipPassword       => $trunk_svc->sip_password,
  };
  $result = $self->api_request('PUT', $endpoint, $content);

  if ( $result->{Reply} != 1 ) {
    die "$me ".$result->{Message};
  }
}

sub export_delete {
  my ($self, $svc_x) = (shift, shift);

  my $role = $self->svc_role($svc_x)
    or return; # not really an error
  my $pkgnum = $svc_x->cust_svc->pkgnum;

  # delete_foo(svcnum, identifier, pkgnum)
  # so that we can find the linked services later

  if ( $role eq 'trunk' ) {
    $self->queue_action("delete_trunk", $svc_x->svcnum, $svc_x->phonenum, $pkgnum);
  } elsif ( $role eq 'did' ) {
    $self->queue_action("delete_did", $svc_x->svcnum, $svc_x->phonenum, $pkgnum);
  } elsif ( $role eq 'gateway' ) {
    $self->queue_action("delete_gateway", $svc_x->svcnum, $svc_x->uuid, $pkgnum);
  }
}

sub delete_trunk {
  my ($exportnum, $svcnum, $phonenum, $pkgnum) = @_;
  my $self = FS::part_export->by_key($exportnum);

  my $endpoint = "SipTrunks/$phonenum";

  my $result = $self->api_request('DELETE', $endpoint);
  if ( $result->{Reply} != 1 ) {
    die "$me ".$result->{Message};
  }

  # deleting this on the server side should remove all DIDs, but we still
  # need to remove IP bindings
  my @gateways = $self->svc_with_role($pkgnum, 'gateway');
  foreach (@gateways) {
    $_->export_delete;
  }
}

sub delete_did {
  my ($exportnum, $svcnum, $phonenum, $pkgnum) = @_;
  my $self = FS::part_export->by_key($exportnum);

  my $endpoint = "V911s/$phonenum";

  my $result = $self->api_request('DELETE', $endpoint);
  if ( $result->{Reply} != 1 ) {
    warn "$me ".$result->{Message}; # but continue removing the DID
  }

  my $trunk_svc = $self->svc_with_role($pkgnum, 'trunk')
    or return ''; # then it's already been removed, most likely

  my $trunknum = $trunk_svc->phonenum;
  $endpoint = "SipTrunks/$trunknum/Dids/$phonenum";

  $result = $self->api_request('DELETE', $endpoint);
  if ( $result->{Reply} != 1 ) {
    die "$me ".$result->{Message};
  }
}

sub delete_gateway {
  my ($exportnum, $svcnum, $binding_id, $pkgnum) = @_;
  my $self = FS::part_export->by_key($exportnum);

  my $trunk_svc = $self->svc_with_role($pkgnum, 'trunk');
  if ( $trunk_svc ) {
    # detach the address from the trunk
    my $trunknum = $trunk_svc->phonenum;
    my $endpoint = "SipTrunks/$trunknum/Lines/$binding_id";
    my $result = $self->api_request('DELETE', $endpoint);
    if ( $result->{Reply} != 1 ) {
      die "$me ".$result->{Message};
    }
  }

  # seems not to be necessary?
  #my $endpoint = "SipBindings/$binding_id";
  #my $result = $self->api_request('DELETE', $endpoint);
  #if ( $result->{Reply} != 1 ) {
  #  die "$me ".$result->{Message};
  #}
}

sub e911_content {
  my ($self, $svc_x) = @_;

  my %location = $svc_x->location_hash;
  my $cust_main = $svc_x->cust_main;

  my $content = {
    City            => $location{'city'},
    FirstName       => $cust_main->first,
    LastName        => $cust_main->last,
    Number          => $svc_x->phonenum,
    OtherInfo       => ($svc_x->phone_name || ''),
    PostalZip       => $location{'zip'},
    ProvinceState   => $location{'state'},
    SuiteNumber     => $location{'address2'},
  };
  if ($location{address1} =~ /^(\w+) +(.*)$/) {
    $content->{StreetNumber} = $1;
    $content->{StreetName} = $2;
  } else {
    $content->{StreetNumber} = '';
    $content->{StreetName} = $location{address1};
  }

  return $content;
}

# select by province + ratecenter, not by NPA
sub get_dids_npa_select { 0 }

sub get_dids {
  my $self = shift;
  local $DEBUG = 0;

  my %opt = @_;

  my ($exportnum) = $self->exportnum =~ /^(\d+)$/;

  if ( $opt{'region'} ) {

    # return numbers (probably shouldn't cache this)
    my $state = $self->ratecenter_cache->{city}{ $opt{'region'} };
    my $ratecenter = $opt{'region'} . ', ' . $state;
    my $endpoint = uri_escape("RateCenters/$ratecenter/Next10");
    my $result = $self->api_request('GET', $endpoint);
    if (ref($result) eq 'HASH') {
      die "$me error fetching available DIDs in '$ratecenter': ".$result->{Message}."\n";
    }
    my @return;
    foreach my $row (@$result) {
      push @return, $row->{Number};
    }
    return \@return;

  } else {

    if ( $opt{'state'} ) {

      # ratecenter_cache will refresh the cache if necessary, and die on 
      # failure. default here is only in case someone gives us a state that
      # doesn't exist.
      return $self->ratecenter_cache->{province}->{ $opt{'state'} } || [];

    } else {

      return $self->ratecenter_cache->{all_provinces};

    }
  }
}

sub ratecenter_cache {
  # in-memory caching is probably sufficient...Thinktel's API is pretty fast
  my $self = shift;

  if (keys(%CACHE) == 0 or ($last_cache_update + $cache_timeout < time) ) {
    %CACHE = ( province => {}, city => {} );
    my $result = $self->api_request('GET', 'RateCenters');
    if (ref($result) eq 'HASH') {
      die "$me error fetching ratecenters: ".$result->{Message}."\n";
    }
    foreach my $row (@$result) {
      my ($city, $province) = split(', ', $row->{Name});
      $CACHE{province}->{$province} ||= [];
      push @{ $CACHE{province}->{$province} }, $city;
      $CACHE{city}{$city} = $province;
    }
    $CACHE{all_provinces} = [ sort keys %{ $CACHE{province} } ];
    $last_cache_update = time;
  }
  
  return \%CACHE;
}

=item queue_api_request METHOD, ENDPOINT, CONTENT, JOB

Adds a queue job to make a REST request.

=item api_request METHOD, ENDPOINT[, CONTENT ]

Makes a REST request using METHOD, to URL ENDPOINT (relative to the API
base). For POST or PUT requests, CONTENT is the content to submit, as a
hashref. Returns the decoded response; generally, on failure, this will
have a 'Message' element.

=cut

sub api_request {
  my $self = shift;
  my ($method, $endpoint, $content) = @_;
  my $json = JSON->new->canonical(1); # hash keys are ordered

  $DEBUG ||= 1 if $self->option('debug');

  my $url = $base_url . $endpoint;
  if ( ref($content) ) {
    $content = $json->encode($content);
  }

  # PUT() == _simple_req('PUT'), etc.
  my $request = HTTP::Request::Common::_simple_req(
    $method,
    $url,
    'Accept'        => 'text/json',
    'Content-Type'  => 'text/json',
    'Content'       => $content,
  );

  $request->authorization_basic(
    $self->option('username'), $self->option('password')
  );

  my $stringify = 'content';
  $stringify = 'as_string' if $DEBUG > 1; # includes HTTP headers
  warn "$me $method $endpoint\n" . $request->$stringify ."\n" if $DEBUG;
  my $ua = LWP::UserAgent->new;
  my $response = $ua->request($request);
  warn "$me received:\n" . $response->$stringify ."\n" if $DEBUG;
  if ( ! $response->is_success ) {
    # fake up a response
    return { Message => $response->content };
  }

  return $json->decode($response->content);
}

1;
