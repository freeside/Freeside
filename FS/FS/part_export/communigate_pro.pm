package FS::part_export::communigate_pro;

use vars qw(@ISA);
use FS::part_export;
use FS::queue;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my( $self, $svc_acct ) = (shift, shift);
  $self->communigate_pro_queue( $svc_acct->svcnum, 'CreateAccount',
    'accountName'    => $svc_acct->email,
    'accountType'    => $self->option('accountType'),
    'externalFlag'   => $self->option('externalFlag'),
    'AccessModes'    => $self->option('AccessModes'),
    'RealName'       => $svc_acct->finger,
    'MaxAccountSize' => $svc_acct->quota,
    'Password'       => $svc_acct->_password,
  );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't (yet) change domain with CommuniGate Pro"
    if $old->domain ne $new->domain;
  return "can't (yet) change username with CommuniGate Pro"
    if $old->username ne $new->username;
  return "can't (yet) change GECOS with CommuniGate Pro"
    if $old->finger ne $new->finger;
  return "can't (yet) change quota with CommuniGate Pro"
    if $old->quota ne $new->quota;
  return '' unless $old->username ne $new->username
                || $old->_password ne $new->_password
                || $old->finger ne $new->finger
                || $old->quota ne $new->quota;

  #my $err_or_queue = $self->communigate_pro_queue( $new->svcnum,'RenameAccount',
  #  $old->email, $new->email );
  #return $err_or_queue unless ref($err_or_queue);
  #my $jobnum = $err_or_queue->jobnum;

  $self->communigate_pro_queue( $new->svcnum, 'SetAccountPassword',
                                $new->email, $new->_password        )
    if $new->_password ne $old->_password;

}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $self->communigate_pro_queue( $svc_acct->svcnum, 'DeleteAccount',
    $svc_acct->email,
  );
}

#sub _export_suspend {
#}

#sub _export_unsuspend {
#}

sub communigate_pro_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $sub = $method eq 'CreateAccount'
              ? 'CreateAccount'
              : 'communigate_pro_command';
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::communigate_pro::$sub",
  };
  $queue->insert(
    $self->machine,
    $self->option('port'),
    $self->option('login'),
    $self->option('password'),
    $method,
    @_,
  );

}

sub CreateAccount {
  my( $machine, $port, $login, $password, $method, @args ) = @_;

  my %args = @args;
  my $accountName  = delete $args{'accountName'};
  my $accountType  = delete $args{'accountType'};
  my $externalFlag = delete $args{'externalFlag'};
  $args{'AccessModes'} = [ split(' ', $args{'AccessModes'}) ];
  @args = ( accountName => $accountName,
            accountType  => $accountType,
            settings     => \%args,
          );
            #externalFlag => $externalFlag,
  push @args, externalFlag => $externalFlag if $externalFlag;

  communigate_pro_command( $machine, $port, $login, $password, $method, @args );

}

sub communigate_pro_command { #subroutine, not method
  my( $machine, $port, $login, $password, $method, @args ) = @_;

  eval "use CGP::CLI";

  my $cli = new CGP::CLI( {
    'PeerAddr' => $machine,
    'PeerPort' => $port,
    'login'    => $login,
    'password' => $password,
  } ) or die "Can't login to CGPro: $CGP::ERR_STRING\n";

  $cli->$method(@args) or die "CGPro error: ". $cli->getErrMessage;

  $cli->Logout or die "Can't logout of CGPro: $CGP::ERR_STRING\n";

}
