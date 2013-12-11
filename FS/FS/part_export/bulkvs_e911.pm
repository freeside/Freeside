package FS::part_export::bulkvs_e911;

use strict;
use vars qw(%info $me $DEBUG);
use base 'FS::part_export';
use FS::svc_phone;
use Tie::IxHash;

use SOAP::Lite;
use Digest::MD5 'md5_hex';
use Data::Dumper;

$DEBUG = 2;
$me = '['.__PACKAGE__.']';

tie my %options, 'Tie::IxHash', (
  'apikey'    => { label=>'Bulkvs.com API key' },
  'password'  => { label=>'Bulkvs.com website password' },
);

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision e911 services via BulkVS',
  'notes'   => <<END
<p>Provision e911 services via BulkVS.  Currently does not support provisioning
phone numbers, only e911 service itself.</p>
<p><i>apikey</i> is available through the web interface (look under the E911 
Portal submenu). <i>password</i> is your password for the website, which will
be used to calculate your API password.</p>
END
  ,
  'no_machine' => 1,
  'options' => \%options,
);

my $client;

sub client {
  my $self = shift;
  my $endpoint = 'https://portal.bulkvs.com/api';
  my $wsdl = $endpoint . '?wsdl';
  # it's expensive to create but completely stateless, so cache it freely
  $client ||= SOAP::Lite->service( $wsdl )->proxy( $endpoint );
}

sub login {
  my $self = shift;
  my $apikey = $self->option('apikey')
      or die "no Bulkvs.com API key configured";
  my $pass = $self->option('password')
      or die "no Bulkvs.com password configured";

  ( $apikey, md5_hex($pass) );
}

sub _export_insert {
  my ($self, $svc_phone) = @_;
  my @login = $self->login;

  my $location = $svc_phone->cust_location_or_main
    or return 'no e911 location defined for this phone service';

  warn "$me validating address for svcnum ".$svc_phone->svcnum."\n"
    if $DEBUG;
  my $result = $self->client->e911validateAddress( @login,
    $location->address1,
    $location->address2,
    $location->city,
    $location->state,
    $location->zip,
  );
  warn Dumper $result if $DEBUG > 1;
  if ( $result->{'faultstring'} ) {
    return "E911 provisioning error: ".$result->{'faultstring'};
  } elsif ( !exists($result->{entry0}->{addressid}) ) {
    return "E911 provisioning error: server returned no address ID";
  }

  my $caller_name = $svc_phone->cust_linked ?
                    $svc_phone->cust_main->name_short :
                    'unknown';

  warn "$me provisioning address for svcnum ".$svc_phone->svcnum."\n"
    if $DEBUG;
  $result = $self->client->e911provisionAddress( @login,
    '1'.$svc_phone->phonenum,
    $caller_name,
    $result->{entry0}->{addressid},
  );
  warn Dumper $result if $DEBUG > 1;
  if ( $result->{'faultstring'} ) {
    return "E911 provisioning error: ".$result->{'faultstring'};
  }
  '';
}

sub _export_delete {
  my ($self, $svc_phone) = @_;
  my @login = $self->login;
  warn "$me removing address for svcnum ".$svc_phone->svcnum."\n"
    if $DEBUG;
  my $result = $self->client->e911removeRecord( @login,
    '1'.$svc_phone->phonenum
  );
  warn Dumper $result if $DEBUG > 1;
  if ( $result->{'faultstring'} ) {
    return "E911 unprovisioning error: ".$result->{'faultstring'};
  }
  '';
}

sub _export_replace {
  my ($self, $new, $old) = @_;
  # BulkVS says that to change an address for an existing number,
  # we should reprovision it without removing the old record.
  if ( $new->phonenum ne $old->phonenum ) {
    my $error = $self->_export_delete($old);
    return $error if $error;
  }
  $self->_export_insert($new);
}

1;

