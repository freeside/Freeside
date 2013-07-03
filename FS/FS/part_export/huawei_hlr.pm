package FS::part_export::huawei_hlr;

use vars qw(@ISA %info $DEBUG $CACHE);
use Tie::IxHash;
use FS::Record qw(qsearch qsearchs dbh);
use FS::part_export;
use FS::svc_phone;
use FS::inventory_class;
use FS::inventory_item;
use IO::Socket::INET;
use Data::Dumper;
use MIME::Base64 qw(decode_base64);
use Storable qw(thaw);

use strict;

$DEBUG = 0;
@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'opname'    => { label=>'Operator login (required)' },
  'pwd'       => { label=>'Operator password (required)' },
  'tplid'     => { label=>'Template number' },
  'hlrsn'     => { label=>'HLR serial number' },
  'k4sno'     => { label=>'K4 serial number' },
  'cardtype'  => { label  => 'Card type (required)',
                   type   => 'select', 
                   options=> ['SIM', 'USIM']
                 },
  'alg'       => { label  => 'Authentication algorithm (required)',
                   type   => 'select',
                   options=> ['COMP128_1',
                              'COMP128_2',
                              'COMP128_3',
                              'MILENAGE' ],
                 },
  'opcvalue'  => { label=>'OPC value (for MILENAGE only)' },
  'opsno'     => { label=>'OP serial number (for MILENAGE only)' },
  'timeout'   => { label=>'Timeout (seconds)', default => 120 },
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

sub actions {
  'Import SIMs' => 'misc/part_export/huawei_hlr-import_sim.html'
}

sub _export_insert {
  my( $self, $svc_phone ) = (shift, shift);
  # svc_phone::check should ensure phonenum and sim_imsi are numeric
  my @command = (
    IMSI   => '"'.$svc_phone->sim_imsi.'"',
    ISDN   => '"'.$svc_phone->countrycode.$svc_phone->phonenum.'"',
    TPLID  => $self->option('tplid'),
  );
  unshift @command, 'HLRSN', $self->option('hlrsn')
    if $self->option('hlrsn');
  unshift @command, 'ADD TPLSUB';
  my $err_or_queue = $self->queue_command($svc_phone->svcnum, @command);
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_replace  {
  my( $self, $new, $old ) = @_;
  my $depend_jobnum;
  if ( $new->sim_imsi ne $old->sim_imsi ) {
    my @command = (
      'MOD IMSI',
      ISDN    => '"'.$old->countrycode.$old->phonenum.'"',
      IMSI    => '"'.$old->sim_imsi.'"',
      NEWIMSI => '"'.$new->sim_imsi.'"',
    );
    my $err_or_queue = $self->queue_command($new->svcnum, @command);
    return $err_or_queue unless ref $err_or_queue;
    $depend_jobnum = $err_or_queue->jobnum;
  }
  if ( $new->countrycode ne $old->countrycode or 
       $new->phonenum ne $old->phonenum ) {
    my @command = (
      'MOD ISDN',
      ISDN    => '"'.$old->countrycode.$old->phonenum.'"',
      NEWISDN => '"'.$new->countrycode.$new->phonenum.'"',
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
    ISDN    => '"'.$svc_phone->countrycode.$svc_phone->phonenum.'"',
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
    #IMSI    => '"'.$svc_phone->sim_imsi.'"',
    ISDN    => '"'.$svc_phone->countrycode.$svc_phone->phonenum.'"',
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
  $string .= "\n;";
  my @result;
  eval { # timeout
    local $SIG{ALRM} = sub { die "timeout\n" };
    alarm ($self->option('timeout') || 120);
    warn "Sending to server:\n$string\n\n" if $DEBUG;
    $socket->print($string);
    warn "Received:\n";
    my $line;
    local $/ = "\r\n";
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
    my $header = shift(@result);
    $header =~ /(\+\+\+.*)/
      or return { error => 'malformed response: '.$header };
    $return{header} = $1;
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

sub process_import_sim {
  my $job = shift;
  my $param = thaw(decode_base64(shift));
  $param->{'job'} = $job;
  my $exportnum = delete $param->{'exportnum'};
  my $export = __PACKAGE__->by_key($exportnum);
  my $file = delete $param->{'uploaded_files'};
  $file =~ s/^file://;
  my $dir = $FS::UID::cache_dir .'/cache.'. $FS::UID::datasrc;
  open( $param->{'filehandle'}, '<', "$dir/$file" )
    or die "unable to open '$file'.\n";
  my $error = $export->import_sim($param);
}

sub import_sim {
  # import a SIM list
  local $FS::UID::AutoCommit = 1; # yes, 1
  my $self = shift;
  my $param = shift;
  my $job = $param->{'job'};
  my $fh = $param->{'filehandle'};
  my @lines = $fh->getlines;

  my @command = 'ADD KI';
  push @command, ('HLRSN', $self->option('hlrsn')) if $self->option('hlrsn');

  my @args = ('OPERTYPE', 'ADD');
  push @args, ('K4SNO', $self->option('k4sno')) if $self->option('k4sno');
  push @args, ('CARDTYPE', $self->option('cardtype'),
               'ALG',      $self->option('alg'));
  push @args, ('OPCVALUE', $self->option('opcvalue'),
               'OPSNO',    $self->option('opsno'))
    if $self->option('alg') eq 'MILENAGE';

  my $agentnum = $param->{'agentnum'};
  my $classnum = $param->{'classnum'};
  my $class = FS::inventory_class->by_key($classnum)
    or die "bad inventory class $classnum\n";
  my %existing = map { $_->item, 1 } 
    qsearch('inventory_item', { 'classnum' => $classnum });

  my $socket = $self->login;
  my $num=0;
  my $total = scalar(@lines);
  foreach my $line (@lines) {
    $num++;
    $job->update_statustext(int(100*$num/$total).',Provisioning IMSIs...')
      if $job;

    chomp $line;
    my ($imsi, $iccid, $pin1, $puk1, $pin2, $puk2, $acc, $ki) = 
      split(' ', $line);
    # the only fields we really care about are the IMSI and KI.
    if ($imsi !~ /^\d{15}$/ or $ki !~ /^[0-9A-Z]{32}$/) {
      warn "misspelled line in SIM file: $line\n";
      next;
    }
    if ($existing{$imsi}) {
      warn "IMSI $imsi already in inventory, skipped\n";
      next;
    }

    # push IMSI/KI to the HLR
    my $return = $self->command($socket,
      @command,
      'IMSI', qq{"$imsi"},
      'KIVALUE', qq{"$ki"},
      @args
    );
    if ( $return->{success} ) {
      # add to inventory
      my $item = FS::inventory_item->new({
          'classnum'  => $classnum,
          'agentnum'  => $agentnum,
          'item'      => $imsi,
      });
      my $error = $item->insert;
      if ( $error ) {
        die "IMSI $imsi added to HLR, but not to inventory:\n$error\n";
      }
    } else {
      die "IMSI $imsi could not be added to HLR:\n".$return->{error}."\n";
    }
  } #foreach $line
  $self->logout($socket);
  return;
}

1;
