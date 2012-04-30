package FS::part_export::netsapiens;

use vars qw(@ISA $me %info);
use MIME::Base64;
use Tie::IxHash;
use FS::part_export;
use Date::Format qw( time2str );
use Regexp::Common qw/URI/;

@ISA = qw(FS::part_export);
$me = '[FS::part_export::netsapiens]';

#These export options set default values for the various commands
#to create/update objects.  Add more options as needed.

my %tristate = ( type => 'select', options => [ '', 'yes', 'no' ]);

tie my %subscriber_fields, 'Tie::IxHash',
  'admin_vmail'     => { label=>'VMail Prov.', %tristate },
  'dial_plan'       => { label=>'Dial Translation' },
  'dial_policy'     => { label=>'Dial Permission' },
  'call_limit'      => { label=>'Call Limit' },
  'domain_dir'      => { label=>'Dir Lst', %tristate },
;

tie my %registrar_fields, 'Tie::IxHash',
  'authenticate_register' => { label=>'Authenticate Registration', %tristate },
  'authentication_realm'  => { label=>'Authentication Realm' },
;

tie my %dialplan_fields, 'Tie::IxHash',
  'responder'       => { label=>'Application' }, #this could be nicer
  'from_name'       => { label=>'Source Name Translation' },
  'from_user'       => { label=>'Source User Translation' },
;

my %features = (
  'for' => 'Forward',
  'fnr' => 'Forward Not Registered',
  'fna' => 'Forward No Answer',
  'fbu' => 'Forward Busy',
  'dnd' => 'Do-Not-Disturb',
  'sim' => 'Simultaneous Ring',
);

tie my %options, 'Tie::IxHash',
  'login'           => { label=>'NetSapiens tac2 User API username' },
  'password'        => { label=>'NetSapiens tac2 User API password' },
  'url'             => { label=>'NetSapiens tac2 User URL' },
  'device_login'    => { label=>'NetSapiens tac2 Device API username' },
  'device_password' => { label=>'NetSapiens tac2 Device API password' },
  'device_url'      => { label=>'NetSapiens tac2 Device URL' },
  'domain'          => { label=>'NetSapiens Domain' },
  'domain_no_tld'   => { label=>'Omit TLD from domains', type=>'checkbox' },
  'debug'           => { label=>'Enable debugging', type=>'checkbox' },
  %subscriber_fields,
  'features'        => { label        => 'Default features',
                         type         => 'select',
                         multiple     => 1,
                         options      => [ keys %features ],
                         option_label => sub { $features{$_[0]}; },
                       },
  %registrar_fields,
  %dialplan_fields,
  'did_countrycode' => { label=>'Use country code in DID destination',
                         type =>'checkbox' },
;

%info = (
  'svc'      => [ 'svc_phone', ], # 'part_device',
  'desc'     => 'Provision phone numbers to NetSapiens',
  'options'  => \%options,
  'notes'    => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/REST-Client">REST::Client</a>
from CPAN.
END
);

# http://devguide.netsapiens.com/

sub rebless { shift; }


sub check_options {
  my ($self, $options) = @_;
	
  my $rex = qr/$RE{URI}{HTTP}{-scheme => qr|https?|}/;			# match any "http:" or "https:" URL
	
  for my $key (qw/url device_url/) {
    if ($$options{$key} && ($$options{$key} !~ $rex)) {
      return "Invalid (URL): " . $$options{$key};
    }
  }
  return '';
}



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

  # kludge to curb excessive paranoia in LWP 6.0+
  local $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
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

sub ns_domain {
  my($self, $svc_phone) = (shift, shift);
  my $domain = $svc_phone->domain || $self->option('domain');

  $domain =~ s/\.\w{2,4}$//
    if $self->option('domain_no_tld');
  
  $domain;
}

sub ns_subscriber {
  my($self, $svc_phone) = (shift, shift);

  my $domain = $self->ns_domain($svc_phone);
  my $phonenum = $svc_phone->phonenum;

  "/domains_config/$domain/subscriber_config/$phonenum";
}

sub ns_registrar {
  my($self, $svc_phone) = (shift, shift);

  $self->ns_subscriber($svc_phone).
    '/registrar_config/'. $self->ns_devicename($svc_phone);
}

sub ns_feature {
  my($self, $svc_phone, $feature) = (shift, shift, shift);

  $self->ns_subscriber($svc_phone).
    "/feature_config/$feature,*,*,*,*";

}

sub ns_devicename {
  my( $self, $svc_phone ) = (shift, shift);

  my $domain = $self->ns_domain($svc_phone);
  #my $countrycode = $svc_phone->countrycode;
  my $phonenum    = $svc_phone->phonenum;

  #"sip:$countrycode$phonenum\@$domain";
  "sip:$phonenum\@$domain";
}

sub ns_dialplan {
  my($self, $svc_phone) = (shift, shift);

  my $countrycode = $svc_phone->countrycode || '1';
  my $phonenum    = $svc_phone->phonenum;
  # Only in the dialplan destination, nowhere else
  if ( $self->option('did_countrycode') ) {
    $phonenum = $countrycode . $phonenum;
  }

  #"/dialplans/DID+Table/dialplan_config/sip:$countrycode$phonenum\@*"
  "/domains_config/admin-only/dialplans/DID+Table/dialplan_config/sip:$phonenum\@*,*,*,*,*,*,*";
}

sub ns_device {
  my($self, $svc_phone, $phone_device ) = (shift, shift, shift);

  #my $countrycode = $svc_phone->countrycode;
  #my $phonenum    = $svc_phone->phonenum;

  "/phones_config/". lc($phone_device->mac_addr);
}

sub ns_create_or_update {
  my($self, $svc_phone, $dial_policy) = (shift, shift, shift);

  my $domain = $self->ns_domain($svc_phone);
  #my $countrycode = $svc_phone->countrycode;
  my $phonenum    = $svc_phone->phonenum;

  #deal w/unaudited netsapiens services?
  my $cust_main = $svc_phone->cust_svc->cust_pkg->cust_main;

  my( $firstname, $lastname );
  if ( $svc_phone->phone_name =~ /^\s*(\S+)\s+(\S.*\S)\s*$/ ) {
    $firstname = $1;
    $lastname  = $2;
  } else {
    $firstname = $cust_main->get('first');
    $lastname  = $cust_main->get('last');
  }

  my ($email) = ($cust_main->invoicing_list_emailonly, '');
  my $custnum = $cust_main->custnum;

  ###
  # Piece 1 (already done) - User creation
  ###
  
  $phonenum =~ /^(\d{3})/;
  my $area_code = $1;

  my $ns = $self->ns_command( 'PUT', $self->ns_subscriber($svc_phone), 
    'subscriber_login' => $phonenum.'@'.$domain,
    'firstname'        => $firstname,
    'lastname'         => $lastname,
    'subscriber_pin'   => $svc_phone->pin,
    'callid_name'      => "$firstname $lastname",
    'callid_nmbr'      => $phonenum,
    'callid_emgr'      => $phonenum,
    'email_address'    => $email,
    'area_code'        => $area_code,
    'srv_code'         => $custnum,
    'date_created'     => time2str('%Y-%m-%d %H:%M:%S', time),
    $self->options_named(keys %subscriber_fields),
    # allow this to be overridden for suspend
    ( $dial_policy ? ('dial_policy' => $dial_policy) : () ),
  );

  if ( $ns->responseCode !~ /^2/ ) {
     return $ns->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns->responseContent ) );
  }

  ###
  # Piece 1.5 - feature creation
  ###
  foreach $feature (split /\s+/, $self->option('features') ) {

    my $nsf = $self->ns_command( 'PUT', $self->ns_feature($svc_phone, $feature),
      'control'    => 'd', #User Control, disable
      'expires'    => 'never',
      #'ts'         => '', #?
      #'parameters' => '',
      'hour_match' => '*',
      'time_frame' => '*',
      'activation' => 'now',
    );

    if ( $nsf->responseCode !~ /^2/ ) {
       return $nsf->responseCode. ' '.
              join(', ', $self->ns_parse_response( $ns->responseContent ) );
    }

  }

  ###
  # Piece 2 - sip device creation 
  ###

  my $ns2 = $self->ns_command( 'PUT', $self->ns_registrar($svc_phone),
    'termination_match' => $self->ns_devicename($svc_phone),
    'authentication_key'=> $svc_phone->sip_password,
    'srv_code'          => $custnum,
    $self->options_named(keys %registrar_fields),
  );

  if ( $ns2->responseCode !~ /^2/ ) {
     return $ns2->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns2->responseContent ) );
  }

  ###
  # Piece 3 - DID mapping to user
  ###

  my $ns3 = $self->ns_command( 'PUT', $self->ns_dialplan($svc_phone),
    'to_user' => $phonenum,
    'to_host' => $domain,
    'plan_description' => "$custnum: $lastname, $firstname", #config?
    $self->options_named(keys %dialplan_fields),
  );

  if ( $ns3->responseCode !~ /^2/ ) {
     return $ns3->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns3->responseContent ) );
  }

  '';
}

sub ns_delete {
  my($self, $svc_phone) = (shift, shift);

  # do the create steps in reverse order, though I'm not sure it matters

  my $ns3 = $self->ns_command( 'DELETE', $self->ns_dialplan($svc_phone) );

  if ( $ns3->responseCode !~ /^2/ ) {
     return $ns3->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns3->responseContent ) );
  }

  my $ns2 = $self->ns_command( 'DELETE', $self->ns_registrar($svc_phone) );

  if ( $ns2->responseCode !~ /^2/ ) {
     return $ns2->responseCode. ' '.
            join(', ', $self->ns_parse_response( $ns2->responseContent ) );
  }

  my $ns = $self->ns_command( 'DELETE', $self->ns_subscriber($svc_phone) );

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
  $self->ns_create_or_update($svc_phone);
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

  my $domain = $self->ns_domain($svc_phone);
  my $countrycode = $svc_phone->countrycode;
  my $phonenum    = $svc_phone->phonenum;

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
      'domain'       => $domain,

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

sub options_named {
  my $self = shift;
  map { 
        my $v = $self->option($_);
        length($v) ? ($_ => $v) : ()
      } @_
}

1;
