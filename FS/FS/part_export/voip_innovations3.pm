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
#not particularly useful unless we can_get_dids
#  'dry_run'       => { label=>"Test mode - don't actually provision",
#                       type=>'checkbox',
#                     },
  'sandbox'       => { label=>'Communicatino with the VoIP Innovations sandbox'.
                              ' instead of the live server',
                       type => 'checkbox',
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

  my $vi = Net::VoIP_Innovations->new(
    'login'    => $self->option('login'),
    'password' => $self->option('password'),
    'sandbox'  => $self->option('sandbox'),
  );

  $vi->$command(@args);
}


sub _export_insert {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  #we want to provision and catch errors now, not queue

  unless ( $self->option('no_provision_did') ) {

    return "can't yet provision to VoIP Innovations v3 API"; #XXX

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
  # insert911
  ###

  if ( $self->option('e911') ) {

    my %location_hash = $svc_phone->location_hash;
    my( $zip, $plus4 ) = split('-', $location_hash->{zip});
    my $resp = $self->vi_command('insert911',
      'did'        => $svc_phone->phonenum,
      'address1'   => $location_hash{address1},
      'address2'   => $location_hash{address2},
      'city'       => $location_hash{city},
      'state'      => $location_hash{state},
      'zip'        => $zip,
      'plusFour'   => $plus4,
      'callerName' =>
        $svc_phone->phone_name
          || $svc_phone->cust_svc->cust_pkg->cust_main->contact_firstlast,
    );

    if ( $resp->{'responseCode'} != 100 ) {
      return "Error running VoIP Innovations insert911: ".
             $resp->{'responseCode'}. ': '. $resp->{'responseMessage'};
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

    my %location_hash = $new->location_hash;
    my( $zip, $plus4 ) = split('-', $location_hash->{zip});
    my $resp = $self->vi_command('update911',
      'did'        => $svc_phone->phonenum,
      'address1'   => $location_hash{address1},
      'address2'   => $location_hash{address2},
      'city'       => $location_hash{city},
      'state'      => $location_hash{state},
      'zip'        => $zip,
      'plusFour'   => $plus4,
      'callerName' =>
        $svc_phone->phone_name
          || $svc_phone->cust_svc->cust_pkg->cust_main->contact_firstlast,
    );

    if ( $resp->{'responseCode'} != 100 ) {
      return "Error running VoIP Innovations update911: ".
             $resp->{'responseCode'}. ': '. $resp->{'responseMessage'};
    }

  }

  '';
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  ###
  # releaseDID
  ###

  unless ( $self->option('no_provision_did') ) {

    return "can't yet provision to VoIP Innovations v3 API"; #XXX

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

  }

  ###
  # remove911
  ###

  if ( $self->option('e911') ) {

    my $resp = $self->vi_command('remove911',
      'did'        => $svc_phone->phonenum,
    );

    if ( $resp->{'responseCode'} != 100 ) {
      return "Error running VoIP Innovations remove911: ".
             $resp->{'responseCode'}. ': '. $resp->{'responseMessage'};
    }

  }

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

