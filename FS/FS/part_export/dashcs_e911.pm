package FS::part_export::dashcs_e911;

use strict;
use vars qw(@ISA %info $me $DEBUG);
use Tie::IxHash;
use FS::part_export;

$DEBUG = 0;
$me = '['.__PACKAGE__.']';

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'username'  => { label=>'Dash username', },
  '_password' => { label=>'Dash password', },
  'staging' => { label=>'Staging (test mode)', type=>'checkbox', },
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision e911 services via Dash Carrier Services',
  'notes'   => 'Provision e911 services via Dash Carrier Services',
  'options' => \%options,
);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_phone) = (shift, shift);
  return 'invalid phonenum' unless $svc_phone->phonenum;
  
  my $opts = { map{ $_ => $self->option($_) } keys %options };
  $opts->{wantreturn} = 1;

  my %location_hash = $svc_phone->location_hash;
  my $location = { 
    'address1'   => $location_hash{address1},
    'address2'   => $location_hash{address2},
    'community'  => $location_hash{city},
    'state'      => $location_hash{state},
    'postalcode' => $location_hash{zip},
  };
  
  my $error_or_ref =
   dash_command($opts, 'validateLocation', { 'location' => $location } );
  return $error_or_ref unless ref($error_or_ref);

  my $status = $error_or_ref->get_Location->get_status; # hate
  return $status->get_description unless $status->get_code eq 'GEOCODED';
  
  my $cust_pkg = $svc_phone->cust_svc->cust_pkg;
  my $cust_main = $cust_pkg->cust_main if $cust_pkg;
  my $caller_name = $cust_main ? $cust_main->name_short : 'unknown';

  my $arg = {
    'uri' => {
               'uri' => 'tel:'. $svc_phone->countrycode. $svc_phone->phonenum,
               'callername' => $caller_name,
             },
    'location' => $location,
  };

  $error_or_ref = dash_command($opts, 'addLocation', $arg );
  return $error_or_ref unless ref($error_or_ref);

  my $id = $error_or_ref->get_Location->get_locationid;
  $self->_export_command('provisionLocation', { 'locationid' => $id });
}

sub _export_delete {
  my($self, $svc_phone) = (shift, shift);
  return '' unless $svc_phone->phonenum;
  
  my $arg = { 'uri' => 'tel:'. $svc_phone->countrycode. $svc_phone->phonenum };
  $self->_export_queue('removeURI', $arg);
}

sub _export_suspend {
  my($self) = shift;
  '';
}

sub _export_unsuspend {
  my($self) = shift;
  '';
}

sub _export_command {
  my $self = shift;

  my $opts = { map{ $_ => $self->option($_) } keys %options };

  dash_command($opts, @_);

}

sub _export_replace {
  my($self, $new, $old ) = (shift, shift, shift);

  # this could succeed in unprovision but fail to provision
  my $arg = { 'uri' => 'tel:'. $old->countrycode. $old->phonenum };
  $self->_export_command('removeURI', $arg) || $self->_export_insert($new);  
}

#a good idea to queue anything that could fail or take any time
sub _export_queue {
  my $self = shift;

  my $opts = { map{ $_ => $self->option($_) } keys %options };

  my $queue = new FS::queue {
    'job'    => "FS::part_export::dashcs_e911::dash_command",
  };
  $queue->insert( $opts, @_ );
}

sub dash_command {
  my ( $opt, $method, $arg ) = (shift, shift, shift);

  warn "$me: dash_command called with method $method\n" if $DEBUG;

  my @module = qw(
    Net::DashCS::Interfaces::EmergencyProvisioningService::EmergencyProvisioningPort
    SOAP::Lite
  );

  foreach my $module ( @module ) {
    eval "use $module;";
    die $@ if $@;
  }

  local *SOAP::Transport::HTTP::Client::get_basic_credentials = sub {
    return ($opt->{'username'}, $opt->{'_password'});
  };

  my $service = new Net::DashCS::Interfaces::EmergencyProvisioningService::EmergencyProvisioningPort(
      { deserializer_args => { strict => 0 } }
  );

  $service->set_proxy('https://staging-service.dashcs.com/dash-api/soap/emergencyprovisioning/v1')
    if $opt->{'staging'};

  my $result = $service->$method($arg);

  if (not $result) {
    warn "returning fault: ". $result->get_faultstring if $DEBUG;
    return ''.$result->get_faultstring;
  }

  warn "returning ok: $result\n" if $DEBUG;
  return $result if $opt->{wantreturn};
  '';
}
