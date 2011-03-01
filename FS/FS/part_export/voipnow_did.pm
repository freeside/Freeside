package FS::part_export::voipnow_did;

use vars qw(@ISA %info $DEBUG $CACHE);
use Tie::IxHash;
use FS::Record qw(qsearch qsearchs dbh);
use FS::part_export;
use FS::areacode;
use XML::Simple 'XMLin';
use Net::SSLeay 'post_https';
use Cache::FileCache;

use strict;

$DEBUG = 0; # 1 = trace operations, 2 = dump XML
@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'login'         => { label=>'VoipNow client login' },
  'password'      => { label=>'VoipNow client password' },
  'country'       => { label=>'Country (two-letter code)' },
  'cache_time'    => { label=>'Cache lifetime (seconds)' },
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision phone numbers to 4PSA VoipNow softswitch',
  'options' => \%options,
  'notes'   => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/XML-Writer">XML::Writer</a>
from CPAN.
END
);

sub rebless { shift; }

sub did_cache {
  my $self = shift;
  $CACHE ||= new Cache::FileCache( { 
      'namespace' => __PACKAGE__,
      'default_expires_in' => $self->option('cache_time') || 300,
      'cache_root' => $FS::UID::cache_dir.'/cache'.$FS::UID::datasrc,
    } );
  return $CACHE->get($self->exportnum) || $self->reload_cache;
}
 
sub get_dids {
  my $self = shift;
  my %opt = @_;

  return [] if $opt{'tollfree'}; # currently not supported

  my %search = ( 'exportnum' => $self->exportnum );

  my $dids = $self->did_cache;

  my ($state, $npa, $nxx) = @opt{'state', 'areacode', 'exchange'};
  $state ||= (FS::areacode->locate($npa))[1];

  if ($nxx) {
    return [ sort keys %{ $dids->{$state}->{$npa}->{"$npa-$nxx"} } ];
  }
  elsif ($npa) {
    return [ sort map { "($_-XXXX)" } keys %{ $dids->{$state}->{$npa} } ];
  }
  elsif ($state) {
    return [ sort keys %{ $dids->{$state} } ];
  }
  else {
    return []; # nothing really to do without state
  }
}

sub reload_cache {
  my $self = shift;
  warn "updating DID cache\n" if $DEBUG;

  my ($response, $error) = 
    $self->voipnow_command('channel', 'GetPublicNoPoll', 
      { 'userID' => $self->userID }
  );

  warn "error updating DID cache: $error\n" if $error;

  my $dids = {};

  my $avail = $response->{'publicNo'}{'available'}
    or return []; # no available numbers
  foreach ( ref($avail) eq 'ARRAY' ? @{ $avail } : $avail ) {
    my $did = $_->{'externalNo'};
    $did =~ /^(\d{3})(\d{3})(\d{4})/ or die "unparseable did $did\n";
    my $state = (FS::areacode->locate($1))[1];
    $dids->{$state}->{$1}->{"$1-$2"}->{"$1-$2-$3"} = $_->{'ID'};
  }

  $CACHE->set($self->exportnum, $dids);
  return $dids;
}

sub _export_insert {
  my( $self, $svc_phone ) = (shift, shift);

  # find remote DID name
  my $phonenum = $svc_phone->phonenum;
  $phonenum =~ /^(\d{3})(\d{3})(\d{4})/
    or die "unparseable phone number: $phonenum";

  warn "checking DID $1-$2-$3\n" if $DEBUG;
  my $state = (FS::areacode->locate($1))[1];

  my $dids = $self->did_cache;
  my $assign_did = $dids->{$state}->{$1}->{"$1-$2"}->{"$1-$2-$3"};
  if ( !defined($assign_did) ) {
    $self->reload_cache; # since it's clearly out of date
    return "phone number $phonenum not available";
  }

  # need to check existence of parent objects?
  my $cust_pkg = $svc_phone->cust_svc->cust_pkg;
  my $cust_main = $cust_pkg->cust_main;

  # this is subject to change
  my %add_extension = (
    namespace('client_data',
      name      => $svc_phone->phone_name || $cust_main->contact_firstlast,
      company   => $cust_main->company,
# to avoid collision with phone numbers, etc.--would be better to store the 
# remote identifier somewhere
      login     => 'S'.$svc_phone->svcnum,
      password  => $svc_phone->sip_password,
      phone     => $cust_main->phone,
      fax       => $cust_main->fax,
      addresss  => $cust_main->address1,
      city      => $cust_main->city,
      pcode     => $cust_main->zip,
      country   => $cust_main->country,
    ),
    parentID  => $self->userID,
    #region--this is a problem
    # Other options named in the documentation:
    #
    # passwordAuto passwordStrength forceUpdate
    # timezone interfaceLang notes serverID chargingIdentifier
    # phoneLang channelRuleId templateID extensionNo extensionType
    # parentIdentifier parentLogin fromUser fromUserIdentifier
    # chargingPlanID chargingPlanIdentifier verbose notifyOnly 
    # scope dku accountFlag
  );
  my ($response, $error) = 
    $self->voipnow_command('extension', 'AddExtension', \%add_extension);
  return "[AddExtension] $error" if $error;

  my $eid = $response->{'ID'};
  warn "Extension created with id=$eid\n" if $DEBUG;

  ($response, $error) = 
    $self->voipnow_command('channel', 'AssignPublicNo', 
      { didID => $assign_did, userID => $eid }
  );
  return "[AssignPublicNo] $error" if $error;
  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  # this could be implemented later
  '';
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  my $eid = $self->extensionID($svc_phone);
  my ($response, $error) = 
    $self->voipnow_command('extension', 'DelExtension', { ID => $eid });
  return "[DelExtension] $error" if $error;
  # don't need to de-assign the DID separately.

  '';
}

sub _export_suspend {
  my( $self, $svc_phone ) = (shift, shift);
  #nop for now
  '';
}

sub _export_unsuspend {
  my( $self, $svc_phone ) = (shift, shift);
  #nop for now
  '';
}

sub userID {
  my $self = shift;
  return $self->{'userID'} if $self->{'userID'};

  my ($response, $error) = $self->voipnow_command('client', 'GetClients', {});
  # GetClients run on a client's login returns only that client.
  die "couldn't get userID: $error" if $error;
  die "non-Client login specified: ".$self->option('login') if
    ref($response->{'client'}) ne 'HASH' 
      or $response->{'client'}->{'login'} ne $self->option('login');
  return $self->{'userID'} = $response->{'client'}->{'ID'};
}

sub extensionID {
  # technically this returns the "extension user ID" rather than 
  # "extension ID".
  my $self = shift;
  my $svc_phone = shift;

  my $login = 'S'.$svc_phone->svcnum;
  my ($response, $error) = 
    $self->voipnow_command('extension', 'GetExtensions', 
      { 'filter'    => $login,
        'parentID'  => $self->userID }
  );
  die "couldn't get extensionID for $login: $error" if $error;
  my $extension = '';

  if ( ref($response->{'extension'}) eq 'HASH' ) {
    $extension = $response->{'extension'};
  }
  elsif ( ref($response->{'extension'}) eq 'ARRAY' ) {
    ($extension) = grep { $_->{'login'} eq $login } 
      @{ $response->{'extension'} };
  }

  die "extension $login not found" if !$extension;

  warn "[extensionID] found ID ".$response->{'extension'}->{'ID'}."\n" 
    if $DEBUG;
  return $response->{'extension'}->{'ID'};
}

my $API_VERSION = '2.5.1';
my %namespaces = (
  'envelope'    => 'http://schemas.xmlsoap.org/soap/envelope/',
  'header'      => 'http://4psa.com/HeaderData.xsd/'.$API_VERSION,
  'channel'     => 'http://4psa.com/ChannelMessages.xsd/'.$API_VERSION,
  'extension'   => 'http://4psa.com/ExtensionMessages.xsd/'.$API_VERSION,
  'client'      => 'http://4psa.com/ClientMessages.xsd/'.$API_VERSION,
  'client_data' => 'http://4psa.com/ClientData.xsd/'.$API_VERSION,
);

# Infrastructure
# example: 
# ($result, $error) = 
#   $self->voipnow_command('endpoint', 'MethodFoo', { argument => 'value' });
# The third argument will be enclosed in a MethodFooRequest and serialized.
# $result is everything inside the MethodFooResponse element, as a tree.

sub voipnow_command {
  my $self = shift;
  my $endpoint = shift; # 'channel' or 'extension'
  my $method = shift;
  my $data = shift;
  my $host = $self->machine;
  my $path = "/soap2/${endpoint}_agent.php";

  eval "use XML::Writer";
  die $@ if $@;

  warn "[$method] constructing request\n" if $DEBUG;
  my $soap_request;
  my $writer = XML::Writer->new(
    OUTPUT => \$soap_request,
    NAMESPACES => 1,
    PREFIX_MAP => { reverse %namespaces },
    FORCED_NS_DECLS => [ values %namespaces ],
    ENCODING => 'utf-8',
  );

  my $header = {
    '#NS' => 'header',
    'userCredentials' => {
      'username' => $self->option('login'),
      'password' => $self->option('password'),
    }
  };
  my $body = {
    '#NS' => $endpoint,
    $method.'Request' => $data,
  };

  # build the request
  descend( $writer,
    { Envelope => { Header => $header, Body => $body } },
    'envelope' #start in this namespace
  );

  warn "SENDING:\n$soap_request\n" if $DEBUG > 1;
  my ($soap_response, $status) = 
    post_https($host, 443, $path, '', $soap_request);
  warn "STATUS: $status\nRECEIVED:\n$soap_response\n" if $DEBUG > 1;
  if ( !length($soap_response) ) {
    return undef, "No response ($status)";
  }

  my $response = eval { strip_ns(XMLin($soap_response)) };
  # handle various errors
  if ( $@ ) {
    return undef, "Parse error: $@";
  }
  if ( !exists $response->{'Body'} ) {
    return undef, "Bad response (missing Body section)";
  }
  $body = $response->{'Body'};
  if ( exists $body->{'Fault'} ) {
    return undef, $body->{'Fault'}->{'faultstring'};
  }
  if ( !exists $body->{"${method}Response"} ) {
    return undef, "Bad response (missing ${method}Response section)";
  }

  return $body->{"${method}Response"};
}

# Infra-infrastructure

sub descend { # like XML::Simple, but more so
  my $writer = shift;
  my $tree = shift;
  my $branch_ns = delete($tree->{'#NS'}) || shift;
  while (my ($key, $val) = each %$tree) {
    my ($name, $key_ns) = reverse split(':', $key);
    $key_ns ||= $branch_ns;
    $name = [ $namespaces{$key_ns}, $name ];
    if ( ref($val) eq 'HASH' ) {
      $writer->startTag($name);
      descend($writer, $val, $key_ns);
      $writer->endTag;
    }
    elsif ( defined($val) ) {
      $writer->dataElement($name, $val);
    }
    else { #undef
      $writer->emptyTag($name);
    }
  }
}

sub namespace {
  my $ns = shift;
  my %data = @_;
  map { $ns.':'.$_ , $data{$_} } keys(%data);
}

sub strip_ns { # remove the namespace tags so that we can find stuff
  my $tree = shift;
  if ( ref $tree eq 'HASH' ) {
    return +{ 
      map {
        my $name = $_;
        $name =~ s/^.*://;
        $name => strip_ns($tree->{$_});
      } keys %$tree
    }
  }
  elsif ( ref $tree eq 'ARRAY' ) {
    return [
      map { strip_ns($_) } @$tree
    ]
  }
  else {
    return $tree;
  }
}

1;

