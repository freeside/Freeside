package FS::part_export::voip_innovations2_e911;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::Record qw(qsearch dbh);
use FS::part_export;
use FS::phone_avail;
use Data::Dumper;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'login'         => { label=>'VoIP Innovations API login' },
  'password'      => { label=>'VoIP Innovations API password' },
  'endpointgroup' => { label=>'VoIP Innovations endpoint group number' },
  'dry_run'       => { label=>"Test mode - don't actually provision",
                       type=>'checkbox',
                     },
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision E911 only to VoIP Innovations (API 2.0)',
  'options' => \%options,
  'no_machine' => 1,
  'notes'   => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/Net-VoIP_Innovations">Net::VoIP_Innovations</a>
from CPAN.
END
);

sub rebless { shift; }

sub gp_command {
  my( $self, $command, @args ) = @_;

  eval "use Net::VoIP_Innovations 2.00;";
  if ( $@ ) {
    warn $@;
    die $@;
  }

  my $gp = Net::VoIP_Innovations->new(
    'login'    => $self->option('login'),
    'password' => $self->option('password'),
    #'debug'    => $debug,
  );

  $gp->$command(@args);
}


sub _export_insert {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  #we want to provision and catch errors now, not queue

  ###
  # 911Insert
  ###

  my %location_hash = $svc_phone->location_hash;
  my( $zip, $plus4 ) = split('-', $location_hash->{zip});
  my $e = $self->gp_command('911Insert',
    'did'        => $svc_phone->phonenum,
    'Address1'   => $location_hash{address1},
    'Address2'   => $location_hash{address2},
    'City'       => $location_hash{city},
    'State'      => $location_hash{state},
    'ZipCode'    => $zip,
    'PlusFour'   => $plus4,
    'CallerName' =>
      $svc_phone->phone_name
        || $svc_phone->cust_svc->cust_pkg->cust_main->contact_firstlast,
  );

  my $edid = $e->{did};

  if ( $edid->{'statuscode'} != 100 ) {
    return "Error running VoIP Innovations 911Insert: ".
           $edid->{'statuscode'}. ': '. $edid->{'status'};
  }

  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  #hmm, anything to change besides E911 data?

  ###
  # 911Update
  ###

  my %location_hash = $svc_phone->location_hash;
  my( $zip, $plus4 ) = split('-', $location_hash->{zip});
  my $e = $self->gp_command('911Update',
    'did'        => $svc_phone->phonenum,
    'Address1'   => $location_hash{address1},
    'Address2'   => $location_hash{address2},
    'City'       => $location_hash{city},
    'State'      => $location_hash{state},
    'ZipCode'    => $zip,
    'PlusFour'   => $plus4,
    'CallerName' =>
      $svc_phone->phone_name
        || $svc_phone->cust_svc->cust_pkg->cust_main->contact_firstlast,
  );

  my $edid = $e->{did};

  if ( $edid->{'statuscode'} != 100 ) {
    return "Error running VoIP Innovations 911Update: ".
           $edid->{'statuscode'}. ': '. $edid->{'status'};
  }

  '';
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  #XXX delete e911 information

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

1;

