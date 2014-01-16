package FS::part_export::voip_innovations3;

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
  'e911'          => { label=>'Provision E911 data',
                       type=>'checkbox',
                     },
  'no_did_provision' => { label=>'Disable DID provisioning',
                       type=>'checkbox',
                     },
  'dry_run'       => { label=>"Test mode - don't actually provision",
                       type=>'checkbox',
                     },
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision phone numbers / E911 to VoIP Innovations (API 3.0)',
  'options' => \%options,
  'no_machine' => 1,
  'notes'   => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/Net-VoIP_Innovations">Net::VoIP_Innovations</a>
from CPAN.
END
);

sub rebless { shift; }

sub can_get_dids { 0; } #with API 3.0?  not yet

sub vi_command {
  my( $self, $command, @args ) = @_;

  eval "use Net::VoIP_Innovations 3.00;";
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

  unless ( $self->option('no_provision_did') ) {

    ###
    # reserveDID
    ###

    my $r = $self->vi_command('reserveDID',
      'did'           => $svc_phone->phonenum,
      'minutes'       => 1,
      'endpointgroup' => $self->option('endpointgroup'),
    );

    my $rdid = $r->{did};

    if ( $rdid->{'statuscode'} != 100 ) {
      return "Error running VoIP Innovations reserveDID: ".
             $rdid->{'statuscode'}. ': '. $rdid->{'status'};
    }

    ###
    # assignDID
    ###

    my $a = $self->vi_command('assignDID',
      'did'           => $svc_phone->phonenum,
      'endpointgroup' => $self->option('endpointgroup'),
      #'rewrite'
      #'cnam'
    );

    my $adid = $a->{did};

    if ( $adid->{'statuscode'} != 100 ) {
      return "Error running VoIP Innovations assignDID: ".
             $adid->{'statuscode'}. ': '. $adid->{'status'};
    }

  }

  ###
  # 911Insert
  ###

  if ( $self->option('e911') ) {

    my %location_hash = $svc_phone->location_hash;
    my( $zip, $plus4 ) = split('-', $location_hash->{zip});
    my $e = $self->vi_command('911Insert',
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

  }

  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  #hmm, anything to change besides E911 data?

  ###
  # 911Update
  ###

  if ( $self->option('e911') ) {

    my %location_hash = $svc_phone->location_hash;
    my( $zip, $plus4 ) = split('-', $location_hash->{zip});
    my $e = $self->vi_command('911Update',
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

  }

  '';
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run')
            || $self->option('no_provision_did');

  #probably okay to queue the deletion...?
  #but hell, let's do it inline anyway, who wants phone numbers hanging around

  my $r = $self->vi_command('releaseDID',
    'did'           => $svc_phone->phonenum,
  );

  my $rdid = $r->{did};

  if ( $rdid->{'statuscode'} != 100 ) {
    return "Error running VoIP Innovations releaseDID: ".
           $rdid->{'statuscode'}. ': '. $rdid->{'status'};
  }

  #delete e911 information?  assuming release clears all that

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

