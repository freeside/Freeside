package FS::part_export::voip_ms;

use base qw( FS::part_export );
use strict;

use Tie::IxHash;
use LWP::UserAgent;
use URI;
use URI::Escape;
use JSON;
use HTTP::Request::Common;
use Cache::FileCache;

our $me = '[voip.ms]';
our $DEBUG = 2;
our $base_url = 'https://voip.ms/api/v1/rest.php';

# cache cities and provinces
our $CACHE; # a FileCache; their API is not as quick as I'd like
our $cache_timeout = 86400; # seconds

tie my %options, 'Tie::IxHash',
  'account'         => { label => 'Main account ID' },
  'username'        => { label => 'API username', },
  'password'        => { label => 'API password', },
  'debug'           => { label => 'Enable debugging', type => 'checkbox', value => 1 },
  # could dynamically pull this from the API...
  'protocol'        => {
    label             => 'Protocol',
    type              => 'select',
    options           => [ 1, 3 ],
    option_labels     => { 1 => 'SIP', 3 => 'IAX' },
  },
  'auth_type'       => {
    label             => 'Authorization type',
    type              => 'select',
    options           => [ 1, 2 ],
    option_labels     => { 1 => 'User/Password', 2 => 'Static IP' },
  },
  'billing_type'    => {
    label             => 'DID billing mode',
    type              => 'select',
    options           => [ 1, 2 ],
    option_labels     => { 1 => 'Per minute', 2 => 'Flat rate' },
  },
  'device_type'     => {
    label             => 'Device type',
    type              => 'select',
    options           => [ 1, 2 ],
    option_labels     => { 1 => 'IP PBX, e.g. Asterisk',
                           2 => 'IP phone or softphone',
                         },
  },
  'canada_routing'    => {
    label             => 'Canada routing policy',
    type              => 'select',
    options           => [ 1, 2 ],
    option_labels     => { 1 => 'Value (lowest price)',
                           2 => 'Premium (highest quality)'
                         },
  },
  'international_route' => { # yes, 'route'
    label             => 'International routing policy',
    type              => 'select',
    options           => [ 0, 1, 2 ],
    option_labels     => { 0 => 'Disable international calls',
                           1 => 'Value (lowest price)',
                           2 => 'Premium (highest quality)'
                         },
  },
  'cnam_lookup' => {
    label             => 'Enable CNAM lookup on incoming calls',
    type              => 'checkbox',
  },

;

tie my %roles, 'Tie::IxHash',
  'subacct'       => {  label     => 'SIP client',
                        svcdb     => 'svc_acct',
                     },
  'did'           => {  label     => 'DID',
                        svcdb     => 'svc_phone',
                        multiple  => 1,
                     },
;

our %info = (
  'svc'      => [qw( svc_acct svc_phone )],
  'desc'     =>
    'Provision subaccounts and DIDs to voip.ms wholesale',
  'options'  => \%options,
  'roles'    => \%roles,
  'no_machine' => 1,
  'notes'    => <<'END'
<P>Export to <b>voip.ms</b> hosted PBX service.</P>
<P>This requires two service definitions to be configured on the same package:
  <OL>
    <LI>An account service for the subaccount (the "login" used by the 
    customer's PBX or IP phone, and the call routing service). This should
    be attached to the export in the "subacct" role. If you are using 
    password authentication, the <i>username</i> and <i>_password</i> will 
    be used to authenticate to voip.ms. If you are using static IP 
    authentication, the <i>slipip</I> (IP address) field should be set to 
    the address.</LI>
    <LI>A phone service for a DID, attached to the export in the DID role.
    You must select a server for the "SIP Host" field. Calls from this DID
    will be routed to the customer via that server.</LI>
  </OL>
</P>
<P>Export options:
  <UL>
    <LI>Main account ID: the numeric ID for the master account. 
    Subaccount usernames will be prefixed with this number and an underscore,
    so if you create a subaccount in Freeside with a username of "myuser", 
    the SIP device will have to authenticate as something like 
    "123456_myuser".</LI>
    <LI>API username/password: your API login; see 
    <a href="https://www.voip.ms/m/api.php">this page</a> to configure it
    if you haven't done so yet.</LI>
    <LI>Enable debugging: writes all traffic with the API server to the log.
    This includes passwords.</LI>
  </UL>
  The other options correspond to options in either the subaccount or DID 
  configuration menu in the voip.ms portal; see documentation there for 
  details.
</P>
END
);

sub export_insert {
  my($self, $svc_x) = (shift, shift);

  my $role = $self->svc_role($svc_x);
  if ( $role eq 'subacct' ) {

    my $error = $self->insert_subacct($svc_x);
    return "$me $error" if $error;

    my @existing_dids = ( $self->svc_with_role($svc_x, 'did') );

    foreach my $svc_phone (@existing_dids) {
      $error = $self->insert_did($svc_phone, $svc_x);
      return "$me $error ordering DID ".$svc_phone->phonenum
        if $error;
    }

  } elsif ( $role eq 'did' ) {

    my $svc_acct = $self->svc_with_role($svc_x, 'subacct');
    return if !$svc_acct;
 
    my $error = $self->insert_did($svc_x, $svc_acct);
    return "$me $error" if $error;

  }
  '';
}

sub export_replace {
  my ($self, $svc_new, $svc_old) = @_;
  my $role = $self->svc_role($svc_new);
  my $error;
  if ( $role eq 'subacct' ) {
    $error = $self->replace_subacct($svc_new, $svc_old);
  } elsif ( $role eq 'did' ) {
    $error = $self->replace_did($svc_new, $svc_old);
  }
  return "$me $error" if $error;
  '';
}

sub export_delete {
  my ($self, $svc_x) = (shift, shift);
  my $role = $self->svc_role($svc_x);
  if ( $role eq 'subacct' ) {

    my @existing_dids = ( $self->svc_with_role($svc_x, 'did') );

    my $error;
    foreach my $svc_phone (@existing_dids) {
      $error = $self->delete_did($svc_phone);
      return "$me $error canceling DID ".$svc_phone->phonenum
        if $error;
    }

    $error = $self->delete_subacct($svc_x);
    return "$me $error" if $error;

  } elsif ( $role eq 'did' ) {

    my $svc_acct = $self->svc_with_role($svc_x, 'subacct');
    return if !$svc_acct;
 
    my $error = $self->delete_did($svc_x);
    return "$me $error" if $error;

  }
  '';
}

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


sub insert_subacct {
  my ($self, $svc_acct) = @_;
  my $method = 'createSubAccount';
  my $content = $self->subacct_content($svc_acct);

  my $result = $self->api_request($method, $content);
  if ( $result->{status} ne 'success' ) {
    return $result->{status}; # or look up the error message string?
  }

  # result includes the account ID and the full username, but we don't
  # really need to keep those; we can look them up later
  '';
}

sub insert_did {
  my ($self, $svc_phone, $svc_acct) = @_;
  my $method = 'orderDID';
  my $content = $self->did_content($svc_phone, $svc_acct);
  my $result = $self->api_request($method, $content);
  if ( $result->{status} ne 'success' ) {
    return $result->{status}; # or look up the error message string?
  }
  '';
}

sub delete_subacct {
  my ($self, $svc_acct) = @_;
  my $account = $self->option('account') . '_' . $svc_acct->username;

  my $id = $self->subacct_id($svc_acct);
  if ( $id =~ /\D/ ) {

    return $id; # it's an error

  } elsif ( $id eq '' ) {

    return ''; # account doesn't exist, don't need to delete

  } # else it's numeric

  warn "$me deleting account $account with ID $id\n" if $DEBUG;
  my $result = $self->api_request('delSubAccount', { id => $id });
  if ( $result->{status} ne 'success' ) {
    return $result->{status};
  }
  '';
}

sub delete_did {
  my ($self, $svc_phone) = @_;
  my $phonenum = $svc_phone->phonenum;

  my $result = $self->api_request('cancelDID', { did => $phonenum });
  if ( $result->{status} ne 'success' and $result->{status} ne 'invalid_did' )
  {
    return $result->{status};
  }
  '';
}

sub replace_subacct {
  my ($self, $svc_new, $svc_old) = @_;
  if ( $svc_new->username ne $svc_old->username ) {
    return "can't change account username; delete and recreate the account instead";
  }
  
  my $id = $self->subacct_id($svc_new);
  if ( $id =~ /\D/ ) {

    return $id;

  } elsif ( $id eq '' ) {

    # account doesn't exist; provision it anew
    return $self->insert_subacct($svc_new);

  }

  my $content = $self->subacct_content($svc_new);
  delete $content->{username};
  $content->{id} = $id;

  my $result = $self->api_request('setSubAccount', $content);
  if ( $result->{status} ne 'success' ) {
    return $result->{status};
  }

  '';
}

sub replace_did {
  my ($self, $svc_new, $svc_old) = @_;
  if ( $svc_new->phonenum ne $svc_old->phonenum ) {
    return "can't change DID phone number";
  }
  # check that there's a subacct set up
  my $svc_acct = $self->svc_with_role($svc_new, 'subacct')
    or return '';

  # check for the existing DID
  my $result = $self->api_request('getDIDsInfo',
    { did => $svc_new->phonenum }
  );
  if ( $result->{status} eq 'invalid_did' ) {

    # provision the DID
    return $self->insert_did($svc_new, $svc_acct);

  } elsif ( $result->{status} ne 'success' ) {

    return $result->{status};

  }

  my $existing = $result->{dids}[0];

  my $content = $self->did_content($svc_new, $svc_acct);
  if ( $content->{billing_type} == $existing->{billing_type} ) {
    delete $content->{billing_type}; # confuses the server otherwise
  }
  $result = $self->api_request('setDIDInfo', $content);
  if ( $result->{status} ne 'success' ) {
    return $result->{status};
  }

  return '';
}

#######################
# CONVENIENCE METHODS #
#######################

sub subacct_id {
  my ($self, $svc_acct) = @_;
  my $account = $self->option('account') . '_' . $svc_acct->username;

  # look up the subaccount's numeric ID
  my $result = $self->api_request('getSubAccounts', { account => $account });
  if ( $result->{status} eq 'invalid_account' ) {
    return '';
  } elsif ( $result->{status} ne 'success' ) {
    return "$result->{status} looking up account ID";
  } else {
    return $result->{accounts}[0]{id};
  }
}

sub subacct_content {
  my ($self, $svc_acct) = @_;

  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;

  my $desc = $svc_acct->finger || $svc_acct->username;
  my $intl = $self->option('international_route');
  my $lockintl = 0;
  if ($intl == 0) {
    $intl = 1; # can't send zero
    $lockintl = 1;
  }

  my %auth;
  if ( $cust_pkg and $cust_pkg->susp > 0 and !$svc_acct->get('unsuspended') ) {
    # we can't explicitly suspend their account, so just set its password to 
    # a partially random string that satisfies the password rules
    # (we still have their real password in the svc_acct record)
    %auth = ( auth_type => 1,
              password  => sprintf('Suspend-%08d', int(rand(100000000)) ),
            );
  } else {
    %auth = ( auth_type => $self->option('auth_type'),
              password  => $svc_acct->_password,
              ip        => $svc_acct->slipip,
            );
  }
  return {
    username            => $svc_acct->username,
    description         => $desc,
    %auth,
    device_type         => $self->option('device_type'),
    canada_routing      => $self->option('canada_routing'),
    lock_international  => $lockintl,
    international_route => $intl,
    # sensible defaults for these
    music_on_hold       => 'default', # silence
    allowed_codecs      => 'ulaw;g729;gsm',
    dtmf_mode           => 'AUTO',
    nat                 => 'yes',
  };
}

sub did_content {
  my ($self, $svc_phone, $svc_acct) = @_;

  my $account = $self->option('account') . '_' . $svc_acct->username;
  my $phonenum = $svc_phone->phonenum;
  # look up POP number (for some reason this is assigned per DID...)
  my $sip_server = $svc_phone->sip_server
    or return "SIP server required";
  my $popnum = $self->cache('server_popnum')->{ $svc_phone->sip_server }
    or return "SIP server '$sip_server' is unknown";
  return {
    did                 => $phonenum,
    routing             => "account:$account",
    # secondary routing options (failovers, voicemail) are outside our 
    # scope here
    # though we could support them using the "forwarddst" field?
    pop                 => $popnum,
    dialtime            => 60, # sensible default, add an option if needed
    cnam                => ($self->option('cnam_lookup') ? 1 : 0),
    note                => $svc_phone->phone_name,
    billing_type        => $self->option('billing_type'),
  };
}

#################
# DID SELECTION #
#################

sub get_dids_npa_select { 0 } # all Canadian VoIP providers seem to have this

sub get_dids {
  my $self = shift;
  my %opt = @_;

  my ($exportnum) = $self->exportnum =~ /^(\d+)$/;

  if ( $opt{'region'} ) {

    # return numbers (probably shouldn't cache this)
    my ($ratecenter, $province) = $opt{'region'} =~ /^(.*), (..)$/;
    my $country = $self->cache('province_country')->{ $province };
    my $result;
    if ( $country eq 'CAN' ) {
      $result = $self->api_insist('getDIDsCAN',
                                  { province => $province,
                                    ratecenter => $ratecenter
                                  }
                                 );
    } elsif ( $country eq 'USA' ) {
      $result = $self->api_insist('getDIDsUSA',
                                  { state => $province,
                                    ratecenter => $ratecenter
                                  }
                                 );
    }
    my @return = map { $_->{did} } @{ $result->{dids} };
    return \@return;
  } else {

    if ( $opt{'state'} ) {
      my $province = $opt{'state'};

      # cache() will refresh the cache if necessary, and die on failure.
      # default here is only in case someone gives us a state that
      # doesn't exist.
      return $self->cache('province_city', $province) || [];

    } else {

      # return a list of provinces
      return [
        @{ $self->cache('country_province')->{CAN} },
        @{ $self->cache('country_province')->{USA} },
      ];
    }
  }
}

sub get_sip_servers {
  my $self = shift;
  return [ sort keys %{ $self->cache('server_popnum') } ];
}

sub cache {
  my $self = shift;
  my $element = shift or return;
  my $province = shift;

  $CACHE ||= Cache::FileCache->new({
    'cache_root' => $FS::UID::cache_dir.'/cache'.$FS::UID::datasrc,
    'namespace'  => __PACKAGE__,
    'default_expires_in' => $cache_timeout,
  });

  if ( $element eq 'province_city' ) {
    $element .= ".$province";
  }
  return $CACHE->get($element) || $self->reload_cache($element);
}

sub reload_cache {
  my $self = shift;
  my $element = shift;
  if ( $element eq 'province_country' or $element eq 'country_province' ) {
    # populate provinces/states

    my %province_country;
    my %country_province = ( CAN => [], USA => [] );

    my $result = $self->api_insist('getProvinces');
    foreach my $province (map { $_->{province} } @{ $result->{provinces} }) {
      $province_country{$province} = 'CAN';
      push @{ $country_province{CAN} }, $province;
    }

    $result = $self->api_insist('getStates');
    foreach my $state (map { $_->{state} } @{ $result->{states} }) {
      $province_country{$state} = 'USA';
      push @{ $country_province{USA} }, $state;
    }

    $CACHE->set('province_country', \%province_country);
    $CACHE->set('country_province', \%country_province);
    return $CACHE->get($element);

  } elsif ( $element eq 'server_popnum' ) {

    my $result = $self->api_insist('getServersInfo');
    my %server_popnum;
    foreach (@{ $result->{servers} }) {
      $server_popnum{ $_->{server_hostname} } = $_->{server_pop};
    }

    $CACHE->set('server_popnum', \%server_popnum);
    return \%server_popnum;

  } elsif ( $element =~ /^province_city\.(\w+)$/ ) {

    my $province = $1;

    # then get the ratecenters for that province
    my $country = $self->cache('province_country')->{$province};
    my @ratecenters;

    if ( $country eq 'CAN' ) {

      my $result = $self->api_insist('getRateCentersCAN',
                                   { province => $province });

      foreach (@{ $result->{ratecenters} }) {
        my $ratecenter = $_->{ratecenter} . ", $province"; # disambiguate
        push @ratecenters, $ratecenter;
      }

    } elsif ( $country eq 'USA' ) {

      my $result = $self->api_insist('getRateCentersUSA',
                                   { state => $province });
      foreach (@{ $result->{ratecenters} }) {
        my $ratecenter = $_->{ratecenter} . ", $province";
        push @ratecenters, $ratecenter;
      }

    }

    $CACHE->set($element, \@ratecenters);
    return \@ratecenters;

  } else {
    return;
  }
}

##############
# API ACCESS #
##############

=item api_request METHOD, CONTENT

Makes a REST request with method name METHOD, and POST content CONTENT (as
a hashref).

=cut

sub api_request {
  my $self = shift;
  my ($method, $content) = @_;
  $DEBUG ||= 1 if $self->option('debug');
  my $url = URI->new($base_url);
  $url->query_form(
    'method'        => $method,
    'api_username'  => $self->option('username'),
    'api_password'  => $self->option('password'),
    %$content
  );

  my $request = GET($url,
    'Accept'        => 'text/json',
  );

  warn "$me $method\n" . $request->as_string ."\n" if $DEBUG;
  my $ua = LWP::UserAgent->new;
  my $response = $ua->request($request);
  warn "$me received\n" . $response->as_string ."\n" if $DEBUG;
  if ( !$response->is_success ) {
    return { status => $response->content };
  }

  return decode_json($response->content);
}

=item api_insist METHOD, CONTENT

Exactly like L</api_request>, but if the returned "status" is not "success",
throws an exception.

=cut

sub api_insist {
  my $self = shift;
  my $method = $_[0];
  my $result = $self->api_request(@_);
  if ( $result->{status} eq 'success' ) {
    return $result;
  } elsif ( $result->{status} ) {
    die "$me $method: $result->{status}\n";
  } else {
    die "$me $method: no status returned\n";
  }
}

1;
