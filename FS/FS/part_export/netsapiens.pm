package FS::part_export::netsapiens;

use vars qw(@ISA $me %info);
use URI;
use MIME::Base64;
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);
$me = '[FS::part_export::netsapiens]';

tie my %options, 'Tie::IxHash',
  'login'           => { label=>'NetSapiens tac2 User API username' },
  'password'        => { label=>'NetSapiens tac2 User API password' },
  'url'             => { label=>'NetSapiens tac2 User URL' },
  'device_login'    => { label=>'NetSapiens tac2 Device API username' },
  'device_password' => { label=>'NetSapiens tac2 Device API password' },
  'device_url'      => { label=>'NetSapiens tac2 Device URL' },
  'domain'          => { label=>'NetSapiens Domain' },
  'debug'           => { label=>'Enable debugging', type=>'checkbox' },
;

%info = (
  'svc'      => 'svc_phone',
  'desc'     => 'Provision phone numbers to NetSapiens',
  'options'  => \%options,
  'notes'    => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/REST-Client">REST::Client</a>
from CPAN.
END
);

sub rebless { shift; }

sub ns_command {
  my $self = shift;
  $self->_ns_command('', @_);
}

sub ns_device_command { 
  my $self = shift;
  $self->_ns_command('device_', @_);
}

sub _ns_command {
  my( $self, $prefix, $method, $command ) = splice(@_,0,4);

  eval 'use REST::Client';
  die $@ if $@;

  my $ns = new REST::Client 'host'=>$self->option($prefix.'url');

  my @args = ( $command );

  if ( $method eq 'PUT' ) {
    my $content = $ns->buildQuery( { @_ } );
    $content =~ s/^\?//;
    push @args, $content;
  } elsif ( $method eq 'GET' ) {
    $args[0] .= $ns->buildQuery( { @_ } );
  }

  warn "$me $method ". $self->option($prefix.'url'). join(', ', @args). "\n"
    if $self->option('debug');

  my $auth = encode_base64( $self->option($prefix.'login'). ':'.
                            $self->option($prefix.'password')    );
  push @args, { 'Authorization' => "Basic $auth" };

  $ns->$method( @args );
  $ns;
}

sub ns_subscriber {
  my($self, $svc_phone) = (shift, shift);

  my $domain = $self->option('domain');
  my $phonenum = $svc_phone->phonenum;

  "/domains_config/$domain/subscriber_config/$phonenum";
}

sub ns_registrar {
  my($self, $svc_phone) = (shift, shift);

  $self->ns_subscriber($svc_phone).
    '/registrar_config/'. $self->ns_devicename($svc_phone);
}

sub ns_devicename {
  my( $self, $svc_phone ) = (shift, shift);

  my $domain = $self->option('domain');
  #my $countrycode = $svc_phone->countrycode;
  my $phonenum    = $svc_phone->phonenum;

  #"sip:$countrycode$phonenum\@$domain";
  "sip:$phonenum\@$domain";
}

sub ns_dialplan {
  my($self, $svc_phone) = (shift, shift);

  #my $countrycode = $svc_phone->countrycode;
  my $phonenum    = $svc_phone->phonenum;

  #"/dialplans/DID+Table/dialplan_config/sip:$countrycode$phonenum\@*"
  "/dialplans/DID+Table/dialplan_config/sip:$phonenum\@*"
}

sub ns_device {
  my($self, $svc_phone, $phone_device ) = (shift, shift, shift);

  #my $countrycode = $svc_phone->countrycode;
  #my $phonenum    = $svc_phone->phonenum;

  "/phones_config/". lc($phone_device->mac_addr);
}

sub ns_create_or_update {
  my($self, $svc_phone, $dial_policy) = (shift, shift, shift);

  my $domain = $self->option('domain');
  #my $countrycode = $svc_phone->countrycode;
  my $phonenum    = $svc_phone->phonenum;

  my( $firstname, $lastname );
  if ( $svc_phone->phone_name =~ /^\s*(\S+)\s+(\S.*\S)\s*$/ ) {
    $firstname = $1;
    $lastname  = $2;
  } else {
    #deal w/unaudited netsapiens services?
    my $cust_main = $svc_phone->cust_svc->cust_pkg->cust_main;
    $firstname = $cust_main->get('first');
    $lastname  = $cust_main->get('last');
  }

  # Piece 1 (already done) - User creation

  my $ns = $self->ns_command( 'PUT', $self->ns_subscriber($svc_phone), 
    'subscriber_login' => $phonenum.'@'.$domain,
    'firstname'        => $firstname,
    'lastname'         => $lastname,
    'subscriber_pin'   => $svc_phone->pin,
    'dial_plan'        => 'Default', #config?
    'dial_policy'      => $dial_policy,
  );

  if ( $ns->responseCode !~ /^2/ ) {
     return $ns->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns->responseContent ) );
  }

  #Piece 2 - sip device creation 

  my $ns2 = $self->ns_command( 'PUT', $self->ns_registrar($svc_phone),
    'termination_match' => $self->ns_devicename($svc_phone)
  );

  if ( $ns2->responseCode !~ /^2/ ) {
     return $ns2->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns2->responseContent ) );
  }

  #Piece 3 - DID mapping to user

  my $ns3 = $self->ns_command( 'PUT', $self->ns_dialplan($svc_phone),
    'to_user' => $phonenum,
    'to_host' => $domain,
  );

  if ( $ns3->responseCode !~ /^2/ ) {
     return $ns3->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns3->responseContent ) );
  }

  '';
}

sub ns_delete {
  my($self, $svc_phone) = (shift, shift);

  my $ns = $self->ns_command( 'DELETE', $self->ns_subscriber($svc_phone) );

  #delete other things?

  if ( $ns->responseCode !~ /^2/ ) {
     return $ns->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns->responseContent ) );
  }

  '';

}

sub ns_parse_response {
  my( $self, $content ) = ( shift, shift );

  #try to screen-scrape something useful
  tie my %hash, Tie::IxHash;
  while ( $content =~ s/^.*?<p>\s*<b>(.+?)<\/b>\s*(.+?)\s*<\/p>//is ) {
    ( $hash{$1} = $2 ) =~ s/^\s*<(\w+)>(.+?)<\/\1>/$2/is;
  }

  %hash;
}

sub _export_insert {
  my($self, $svc_phone) = (shift, shift);
  $self->ns_create_or_update($svc_phone, 'Permit All');
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't change phonenum with NetSapiens (unprovision and reprovision?)"
    if $old->phonenum ne $new->phonenum;
  $self->_export_insert($new);
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  $self->ns_delete($svc_phone);
}

sub _export_suspend {
  my( $self, $svc_phone ) = (shift, shift);
  $self->ns_create_or_update($svc_phone, 'Deny');
}

sub _export_unsuspend {
  my( $self, $svc_phone ) = (shift, shift);
  #$self->ns_create_or_update($svc_phone, 'Permit All');
  $self->_export_insert($svc_phone);
}

sub export_device_insert {
  my( $self, $svc_phone, $phone_device ) = (shift, shift, shift);

  #my $domain = $self->option('domain');
  my $countrycode = $svc_phone->countrycode;
  my $phonenum    = $svc_phone->phonenum;

  my $device = $self->ns_devicename($svc_phone);

  my $ns = $self->ns_device_command(
    'PUT', $self->ns_device($svc_phone, $phone_device),
      'line1_enable' => 'yes',
      'device1'      => $self->ns_devicename($svc_phone),
      'line1_ext'    => $phonenum,
,
      #'line2_enable' => 'yes',
      #'device2'      =>
      #'line2_ext'    =>

      #'notes' => 
      'server'       => 'SiPbx',
      'domain'       => $self->option('domain'),

      'brand'        => $phone_device->part_device->devicename,
      
  );

  if ( $ns->responseCode !~ /^2/ ) {
     return $ns->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns->responseContent ) );
  }

  '';

}

sub export_device_delete {
  my( $self, $svc_phone, $phone_device ) = (shift, shift, shift);

  my $ns = $self->ns_device_command(
    'DELETE', $self->ns_device($svc_phone, $phone_device),
  );

  if ( $ns->responseCode !~ /^2/ ) {
     return $ns->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns->responseContent ) );
  }

  '';

}


sub export_device_replace {
  my( $self, $svc_phone, $new_phone_device, $old_phone_device ) =
    (shift, shift, shift, shift);

  #?
  $self->export_device_insert( $svc_phone, $new_phone_device );

}

sub export_links {
  my($self, $svc_phone, $arrayref) = (shift, shift, shift);
  #push @$arrayref, qq!<A HREF="http://example.com/~!. $svc_phone->username.
  #                 qq!">!. $svc_phone->username. qq!</A>!;
  '';
}

1;
