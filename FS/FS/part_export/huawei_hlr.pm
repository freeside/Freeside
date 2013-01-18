package FS::part_export::huawei_hlr;

use vars qw(@ISA %info $DEBUG $CACHE);
use Tie::IxHash;
use FS::Record qw(qsearch qsearchs dbh);
use FS::part_export;
use FS::svc_phone;
use IO::Socket::INET;
use Data::Dumper;

use strict;

$DEBUG = 0;
@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'opname'    => { label=>'Operator login' },
  'pwd'       => { label=>'Operator password' },
  'tplid'     => { label=>'Template number' },
  'hlrsn'     => { label=>'HLR serial number' },
  'debug'     => { label=>'Enable debugging', type=>'checkbox' },
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision mobile phone service to Huawei HLR9820',
  'options' => \%options,
  'notes'   => <<'END'
Connects to a Huawei Subscriber Management Unit via TCP and configures mobile
phone services according to a template.  The <i>sim_imsi</i> field must be 
set on the service, and the template must exist.
END
);

sub _export_insert {
  my( $self, $svc_phone ) = (shift, shift);
  # svc_phone::check should ensure phonenum and sim_imsi are numeric
  my @command = (
    'ADD TPLSUB',
    IMSI   => '"'.$svc_phone->sim_imsi.'"',
    ISDN   => '"'.$svc_phone->phonenum.'"',
    TPLID  => $self->option('tplid'),
  );
  unshift @command, 'HLRSN', $self->option('hlrsn')
    if $self->option('hlrsn');
  my $err_or_queue = $self->queue_command($svc_phone->svcnum, @command);
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_replace  {
  my( $self, $new, $old ) = @_;
  my $depend_jobnum;
  if ( $new->sim_imsi ne $old->sim_imsi ) {
    my @command = (
      'MOD IMSI',
      ISDN    => '"'.$old->phonenum.'"',
      IMSI    => '"'.$old->sim_imsi.'"',
      NEWIMSI => '"'.$new->sim_imsi.'"',
    );
    my $err_or_queue = $self->queue_command($new->svcnum, @command);
    return $err_or_queue unless ref $err_or_queue;
    $depend_jobnum = $err_or_queue->jobnum;
  }
  if ( $new->phonenum ne $old->phonenum ) {
    my @command = (
      'MOD ISDN',
      ISDN    => '"'.$old->phonenum.'"',
      NEWISDN => '"'.$new->phonenum.'"',
    );
    my $err_or_queue = $self->queue_command($new->svcnum, @command);
    return $err_or_queue unless ref $err_or_queue;
    if ( $depend_jobnum ) {
      my $error = $err_or_queue->depend_insert($depend_jobnum);
      return $error if $error;
    }
  }
  # no other svc_phone changes need to be exported
  '';
}

sub _export_suspend {
  my( $self, $svc_phone ) = (shift, shift);
  $self->_export_lock($svc_phone, 'TRUE');
}

sub _export_unsuspend {
  my( $self, $svc_phone ) = (shift, shift);
  $self->_export_lock($svc_phone, 'FALSE');
}

sub _export_lock {
  my ($self, $svc_phone, $lockstate) = @_;
  # XXX I'm not sure this actually suspends.  Need to test it.
  my @command = (
    'MOD LCK',
    IMSI    => '"'.$svc_phone->sim_imsi.'"',
    ISDN    => '"'.$svc_phone->phonenum.'"',
    IC      => $lockstate,
    OC      => $lockstate,
    GPRSLOCK=> $lockstate,
  );
  my $err_or_queue = $self->queue_command($svc_phone->svcnum, @command);
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);
  my @command = (
    'RMV SUB',
    IMSI    => '"'.$svc_phone->sim_imsi.'"',
    ISDN    => '"'.$svc_phone->phonenum.'"',
  );
  my $err_or_queue = $self->queue_command($svc_phone->svcnum, @command);
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub queue_command {
  my ($self, $svcnum, @command) = @_;
  my $queue = FS::queue->new({
      svcnum  => $svcnum,
      job     => 'FS::part_export::huawei_hlr::run_command',
  });
  $queue->insert($self->exportnum, @command) || $queue;
}

sub run_command {
  my ($exportnum, @command) = @_;
  my $self = FS::part_export->by_key($exportnum);
  my $socket = $self->login;
  my $result = $self->command($socket, @command);
  $self->logout($socket);
  $socket->close;
  die $result->{error} if $result->{error};
  '';
}

sub login {
  my $self = shift;
  local $DEBUG = $self->option('debug') || 0;
  # Send a command to the SMU.
  # The caller is responsible for quoting string parameters.
  my %socket_param = (
    PeerAddr  => $self->machine,
    PeerPort  => 7777,
    Proto     => 'tcp',
    Timeout   => ($self->option('timeout') || 30),
  );
  warn "Connecting to ".$self->machine."...\n" if $DEBUG;
  warn Dumper(\%socket_param) if $DEBUG;
  my $socket = IO::Socket::INET->new(%socket_param)
    or die "Failed to connect: $!\n";

  warn 'Logging in as "'.$self->option('opname').".\"\n" if $DEBUG;
  my @login_param = (
    OPNAME => '"'.$self->option('opname').'"',
    PWD    => '"'.$self->option('pwd').'"',
  );
  if ($self->option('HLRSN')) {
    unshift @login_param, 'HLRSN', $self->option('HLRSN');
  }
  my $login_result = $self->command($socket, 'LGI', @login_param);
  die $login_result->{error} if $login_result->{error};
  return $socket;
}

sub logout {
  warn "Logging out.\n" if $DEBUG;
  my $self = shift;
  my ($socket) = @_;
  $self->command($socket, 'LGO');
  $socket->close;
}

sub command {
  my $self = shift;
  my ($socket, $command, @param) = @_;
  my $string = $command . ':';
  while (@param) {
    $string .= shift(@param) . '=' . shift(@param);
    $string .= ',' if @param;
  }
  $string .= "\n";
  my @result;
  eval { # timeout
    local $SIG{ALRM} = sub { die "timeout\n" };
    alarm ($self->option('timeout') || 30);
    warn "Sending to server:\n$string\n\n" if $DEBUG;
    $socket->print($string);
    warn "Received:\n";
    my $line;
    do {
      $line = $socket->getline();
      warn $line if $DEBUG;
      chomp $line;
      push @result, $line if length($line);
    } until ( $line =~ /^---\s*END$/ or $socket->eof );
    alarm 0;
  };
  my %return;
  if ( $@ eq "timeout\n" ) {
    return { error => 'request timed out' };
  } elsif ( $@ ) {
    return { error => $@ };
  } else {
    #+++    HLR9820        <date> <time>\n
    # skip empty lines
    my $header = shift(@result);
    return { error => 'malformed response: '.$header }
      unless $header =~ /^\+\+\+/;
    $return{header} = $header;
    #SMU    #<serial number>\n
    $return{smu} = shift(@result);
    #%%<command string>%%\n 
    $return{echo} = shift(@result); # should match the input
    #<message code>: <message description>\n
    my $message = shift(@result);
    if ($message =~ /^SUCCESS/) {
      $return{success} = $message;
    } else { #/^ERR/
      $return{error} = $message;
    }
    $return{trailer} = pop(@result);
    $return{details} = join("\n",@result,'');
  }
  \%return;
}

1;
