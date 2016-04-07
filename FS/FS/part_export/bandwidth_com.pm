package FS::part_export::bandwidth_com;

use base qw( FS::part_export );
use strict;

use Tie::IxHash;
use LWP::UserAgent;
use URI;
use HTTP::Request::Common;
use Cache::FileCache;
use FS::Record qw(dbh qsearch);
use FS::queue;
use XML::LibXML::Simple qw(XMLin);
use XML::Writer;
use Try::Tiny;

our $me = '[bandwidth.com]';

# cache NPA/NXX records, peer IDs, etc.
our %CACHE; # exportnum => cache
our $cache_timeout = 86400; # seconds

our $API_VERSION = 'v1.0';

tie my %options, 'Tie::IxHash',
  'accountId'       => { label => 'Account ID' },
  'username'        => { label => 'API username', },
  'password'        => { label => 'API password', },
  'siteId'          => { label => 'Site ID' },
  'num_dids'        => { label => 'Maximum available phone numbers to show',
                         default => '20'
                       },
  'debug'           => { label => 'Debugging',
                         type => 'select',
                         options => [ 0, 1, 2 ],
                         option_labels => {
                           0 => 'none',
                           1 => 'terse',
                           2 => 'verbose',
                         }
                       },
  'test'            => { label => 'Use test server', type => 'checkbox', value => 1 },
;

our %info = (
  'svc'      => [qw( svc_phone )],
  'desc'     => 'Provision DIDs to Bandwidth.com',
  'options'  => \%options,
  'no_machine' => 1,
  'notes'    => <<'END'
<P>Export to <b>bandwidth.com</b> interconnected VoIP service.</P>
<P>Bandwidth.com uses a SIP peering architecture. Each phone number is routed
to a specific peer, which comprises one or more IP addresses. The IP address
will be taken from the "sip_server" field of the phone service. If no peer
with this IP address exists, one will be created.</P>
<P>If you are operating a central SIP gateway to receive traffic for all (or
a subset of) customers, you should configure a phone service with a fixed
value, or a list of fixed values, for the sip_server field.</P>
<P>To find your account ID and site ID:
  <UL>
  <LI>Login to <a target="_blank" href="https://dashboard.bandwidth.com">the Dashboard.
  </a></LI>
  <LI>Under "Your subaccounts", find the subaccount (site) that you want to use
  for exported DIDs. Click the "manage sub-account" link.</LI>
  <LI>Look at the URL. It will end in <i>{"a":xxxxxxx,"s":yyyy}</i>.</LI>
  <LI>Your account ID is <i>xxxxxxx</i>, and the site ID is <i>yyyy</i>.</LI>
  </UL>
</P>
END
);

sub export_insert {
  my($self, $svc_phone) = (shift, shift);
  local $SIG{__DIE__};
  try {
    my $account_id = $self->option('accountId');
    my $peer = $self->find_peer($svc_phone)
      or die "couldn't find SIP peer for ".$svc_phone->sip_server.".\n";
    my $phonenum = $svc_phone->phonenum;
    # future: reserve numbers before activating?
    # and an option to order first available number instead of selecting DID?
    my $order = {
      Order => {
        Name      => "Order svc#".$svc_phone->svcnum." - $phonenum",
        SiteId    => $peer->{SiteId},
        PeerId    => $peer->{PeerId},
        Quantity  => 1,
        ExistingTelephoneNumberOrderType => {
          TelephoneNumberList => {
            TelephoneNumber => $phonenum
          }
        }
      }
    };
    my $result = $self->api_post("orders", $order);
    # future: add a queue job here to poll the order completion status.
    '';
  } catch {
    "$me $_";
  };
}

sub export_replace {
  my ($self, $new, $old) = @_;
  # we only export the IP address and the phone number,
  # neither of which we can change in place.
  if (   $new->phonenum ne $old->phonenum
      or $new->sip_server ne $old->sip_server ) {
    return $self->export_delete($old) || $self->export_insert($new);
  }
  '';
}

sub export_delete {
  my ($self, $svc_phone) = (shift, shift);
  local $SIG{__DIE__};
  try {
    my $phonenum = $svc_phone->phonenum;
    my $disconnect = {
      DisconnectTelephoneNumberOrder => {
        Name => "Disconnect svc#".$svc_phone->svcnum." - $phonenum",
        DisconnectTelephoneNumberOrderType => {
          TelephoneNumberList => [
            { TelephoneNumber => $phonenum },
          ],
        },
      }
    };
    my $result = $self->api_post("disconnects", $disconnect);
    # this is also an order, and we could poll its status also
    ''; 
  } catch {
    "$me $_";
  };
}

sub find_peer {
  my $self = shift;
  my $svc_phone = shift;
  my $ip = $svc_phone->sip_server; # future: support svc_pbx for this
  die "SIP server address required.\n" if !$ip;

  my $peers = $self->peer_cache;
  if ( $peers->{hostname}{$ip} ) {
    return $peers->{hostname}{$ip};
  }
  # refresh the cache and try again
  $self->cache->remove('peers');
  $peers = $self->peer_cache;
  return $peers->{hostname}{$ip} || undef;
}

#################
# DID SELECTION #
#################

sub can_get_dids { 1 }

# we don't yet have tollfree support

sub get_dids_npa_select { 1 }

sub get_dids {

  my $self = shift;
  my %opt = @_;

  my ($exportnum) = $self->exportnum =~ /^(\d+)$/;

  try {
    return [] if $opt{'tollfree'}; # we'll come back to this

    my ($state, $npa, $nxx) = @opt{'state', 'areacode', 'exchange'};

    if ( $nxx ) {

      die "areacode required\n" unless $npa;
      my $limit = $self->option('num_dids') || 20;
      my $result = $self->api_get('availableNumbers', [
          'npaNxx'    => $npa.$nxx,
          'quantity'  => $limit,
          'LCA'       => 'false',
          # find only those that match the NPA-NXX, not those thought to be in
          # the same local calling area. though that might be useful.
      ]);
      return [ $result->findnodes('//TelephoneNumber')->to_literal_list ];

    } elsif ( $npa ) {

      return $self->npanxx_cache($npa);

    } elsif ( $state ) {

      return $self->npa_cache($state);

    } else { # something's wrong

      warn "get_dids called with no arguments";
      return [];

    }
  } catch {
    die "$me $_\n";
  }

}

#########
# CACHE #
#########

=item peer_cache

Returns a hashref of information on peer addresses. Currently has one key,
'hostname', pointing to a hash of (IP address => peer ID).

=cut

sub peer_cache {
  my $self = shift;
  my $peer_table = $self->cache->get('peers');
  if (!$peer_table) {
    $peer_table = { hostname => {} };
    my $result = $self->api_get('sites');
    my @site_ids = $result->findnodes('//Site/Id')->to_literal_list;
    foreach my $site_id (@site_ids) {
      $result = $self->api_get("sites/$site_id/sippeers");
      my @peers = $result->findnodes('//SipPeer');
      foreach my $peer (@peers) {
        my $peer_id = $peer->findvalue('PeerId');
        my @hosts = $peer->findnodes('VoiceHosts/Host/HostName')->to_literal_list;
        foreach my $host (@hosts) {
          $peer_table->{hostname}->{ $host } = {
            PeerId => $peer_id,
            SiteId => $site_id,
          };
        }
        # any other peer info we need? I don't think so.
      } # foreach $peer
    } # foreach $site_id
    $self->cache->set('peers', $peer_table, $cache_timeout);
  }
  $peer_table;
}

=item npanxx_cache NPA

Returns an arrayref of exchange prefixes in the areacode NPA. This will
only work if the available prefixes in that areacode's state have already
been loaded.

=cut

sub npanxx_cache {
  my $self = shift;
  my $npa = shift;
  my $exchanges = $self->cache->get("npanxx_$npa");
  if (!$exchanges) {
    warn "NPA $npa not yet loaded; returning nothing";
    return [];
  }
  $exchanges;
}

=item npa_cache STATE

Returns an arrayref of area codes in the state. This will refresh the cache
if necessary.

=cut

sub npa_cache {
  my $self = shift;
  my $state = shift;

  my $npas = $self->cache->get("npa_$state");
  if (!$npas) {
    my $data = {}; # NPA => [ NPANXX, ... ]
    my $result = $self->api_get('availableNpaNxx', [ 'state' => $state ]);
    foreach my $entry ($result->findnodes('//AvailableNpaNxx')) {
      my $npa = $entry->findvalue('Npa');
      my $nxx = $entry->findvalue('Nxx');
      my $city = $entry->findvalue('City');
      push @{ $data->{$npa} ||= [] }, "$city ($npa-$nxx-XXXX)";
    }
    $npas = [ sort keys %$data ];
    $self->cache->set("npa_$state", $npas);
    foreach (@$npas) {
      # sort by city, then NXX
      $data->{$_} = [ sort @{ $data->{$_} } ];
      $self->cache->set("npanxx_$_", $data->{$_});
    }
  }
  return $npas;
}

=item cache

Returns the Cache::FileCache object for this export. Each instance of the
export gets a separate cache.

=cut

sub cache {
  my $self = shift;

  my $exportnum = $self->get('exportnum');
  $CACHE{$exportnum} ||= Cache::FileCache->new({
    'cache_root' => $FS::UID::cache_dir.'/cache.'.$FS::UID::datasrc,
    'namespace'  => __PACKAGE__ . '_' . $exportnum,
    'default_expires_in' => $cache_timeout,
  });

}

##############
# API ACCESS #
##############

sub debug {
  shift->option('debug') || 0;
}

sub api_get {
  my ($self, $path, $content) = @_;
  warn "$me GET $path\n" if $self->debug;
  my $url = URI->new( 'https://' .
    join('/', $self->host, $API_VERSION, 'accounts', $self->option('accountId'), $path)
  );
  $url->query_form($content);
  my $request = GET($url);
  $self->_request($request);
}

sub api_post {
  my ($self, $path, $content) = @_;
  warn "$me POST $path\n" if $self->debug;
  my $url = URI->new( 'https://' .
    join('/', $self->host, $API_VERSION, 'accounts', $self->option('accountId'), $path)
  );
  my $request = POST($url, 'Content-Type' => 'application/xml',
                           'Content' => $self->xmlout($content));
  $self->_request($request);
}

sub api_put {
  my ($self, $path, $content) = @_;
  warn "$me PUT $path\n" if $self->debug;
  my $url = URI->new( 'https://' .
    join('/', $self->host, $API_VERSION, 'accounts', $self->option('accountId'), $path)
  );
  my $request = PUT ($url, 'Content-Type' => 'application/xml',
                           'Content' => $self->xmlout($content));
  $self->_request($request);
}

sub api_delete {
  my ($self, $path) = @_;
  warn "$me DELETE $path\n" if $self->debug;
  my $url = URI->new( 'https://' .
    join('/', $self->host, $API_VERSION, 'accounts', $self->option('accountId'), $path)
  );
  my $request = DELETE($url);
  $self->_request($request);
}

sub xmlout {
  my ($self, $content) = @_;
  my $output;
  my $writer = XML::Writer->new( OUTPUT => \$output, ENCODING => 'utf-8' );
  my @queue = ($content);
  while ( @queue ) {
    my $obj = shift @queue;
    if (ref($obj) eq 'HASH') {
      foreach my $k (keys %$obj) {
        unshift @queue, "endTag $k";
        unshift @queue, $obj->{$k};
        unshift @queue, "startTag $k";
      }
    } elsif ( ref($obj) eq 'ARRAY' ) {
      unshift @queue, @$obj;
    } elsif ( $obj =~ /^startTag (.*)$/ ) {
      $writer->startTag($1);
    } elsif ( $obj =~ /^endTag (.*)$/ ) {
      $writer->endTag($1);
    } elsif ( defined($obj) ) {
      $writer->characters($obj);
    }
  }
  return $output;
}

sub xmlin {
  # wrapper for XML::LibXML::Simple's XMLin, with auto-flattening of NodeLists
  my $self = shift;
  my @out;
  foreach my $node (@_) {
    if ($node->can('get_nodelist')) {
      push @out, map { XMLin($_, KeepRoot => 1) } $node->get_nodelist;
    } else {
      push @out, XMLin($node);
    }
  }
  @out;
}

sub _request { # even lower level
  my ($self, $request) = @_; 
  warn $request->as_string . "\n" if $self->debug > 1;
  my $response = $self->ua->request( $request ); 
  warn "$me received\n" . $response->as_string . "\n" if $self->debug > 1;

  if ($response->content) {

    my $xmldoc = XML::LibXML->load_xml(string => $response->content);
    # errors are found in at least two places: ResponseStatus/ErrorCode
    my $error;
    my ($ec) = $xmldoc->findnodes('//ErrorCode');
    if ($ec) {
      $error = $ec->parentNode->findvalue('Description');
    }
    # and ErrorList/Error
    $error ||= join("; ", $xmldoc->findnodes('//Error/Description')->to_literal_list);
    die "$error\n" if $error;
    return $xmldoc;

  } elsif ($response->code eq '201') { # Created, response to a POST

    return $response->header('Location');

  } else {

    die $response->status_line."\n";
  
  }
}

sub host {
  my $self = shift;
  $self->{_host} ||= do {
    my $host = 'dashboard.bandwidth.com';
    $host = "test.$host" if $self->option('test');
    $host;
  };
}

sub ua {
  my $self = shift;
  $self->{_ua} ||= do {
    my $ua = LWP::UserAgent->new;
    $ua->credentials(
      $self->host . ':443',
      'Bandwidth API',
      $self->option('username'),
      $self->option('password')
    );
    $ua;
  }
}


1;
