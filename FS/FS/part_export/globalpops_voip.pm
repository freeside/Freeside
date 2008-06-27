package FS::part_export::globalpops_voip;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'login'    => { label=>'GlobalPOPs Media Services API login' },
  'password' => { label=>'GlobalPOPs Media Services API password' },
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision phone numbers to GlobalPOPs VoIP',
  'options' => \%options,
  'notes'   => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/Net-GlobalPOPs-MediaServicesAPI">Net::GlobalPOPs::MediaServicesAPI</a>
from CPAN.
END
);

sub rebless { shift; }

sub _export_insert {
  my( $self, $svc_phone ) = (shift, shift);
  #we want to provision and catch errors now, not queue
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  #hmm, what's to change?
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);
  #probably okay to queue the deletion...
}

sub _export_suspend {
  my( $self, $svc_phone ) = (shift, shift);
  #nop for now
}

sub _export_unsuspend {
  my( $self, $svc_phone ) = (shift, shift);
  #nop for now
}

#hmm, might forgo queueing entirely for most things, data is too much of a pita

sub globalpops_voip_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => 'FS::part_export::globalpops_voip::globalpops_voip_command',
  };
  $queue->insert(
    $self->option('login'),
    $self->option('password'),
    $method,
    @_,
  );
}

sub globalpops_voip_command {
  my($login, $password, $method, @args) = @_;

  eval "use Net::GlobalPOPs::MediaServicesAPI;";
  die $@ if $@;

  my $gp = new Net::GlobalPOPs
                 'login'    => $login,
                 'password' => $password,
                 #'debug'    => 1,
               ;

  my $return = $gp->$method( @args );

  #$return->{'status'} 
  #$return->{'statuscode'} 

  die $return->{'status'} if $return->{'statuscode'};

}

1;

