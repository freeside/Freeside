package FS::Daemon;

use vars qw( @ISA @EXPORT_OK );
use vars qw( $pid_dir $me $pid_file $sigint $sigterm $NOSIG $logfile );
use Exporter;
use Fcntl qw(:flock);
use POSIX qw(setsid);
use IO::File;
use Date::Format;

#this is a simple refactoring of the stuff from freeside-queued, just to
#avoid duplicate code.  eventually this should use something from CPAN.

@ISA = qw(Exporter);
@EXPORT_OK = qw(
  daemonize1 drop_root daemonize2 myexit logfile sigint sigterm
);
%EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );

$pid_dir = '/var/run';

$NOSIG = 0;

sub daemonize1 {
  $me = shift;

  $pid_file = "$pid_dir/$me";
  $pid_file .= '.'.shift if scalar(@_);
  $pid_file .= '.pid';

  chdir "/" or die "Can't chdir to /: $!";
  open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
  defined(my $pid = fork) or die "Can't fork: $!";
  if ( $pid ) {
    print "$me started with pid $pid\n"; #logging to $log_file\n";
    exit unless $pid_file;
    my $pidfh = new IO::File ">$pid_file" or exit;
    print $pidfh "$pid\n";
    exit;
  }

  #sub REAPER { my $pid = wait; $SIG{CHLD} = \&REAPER; $kids--; }
  #$SIG{CHLD} =  \&REAPER;
  $sigterm = 0;
  $sigint = 0;
  unless ( $NOSIG ) {
    $SIG{INT}  = sub { warn "SIGINT received; shutting down\n"; $sigint++;  };
    $SIG{TERM} = sub { warn "SIGTERM received; shutting down\n"; $sigterm++; };
  }
}

sub drop_root {
  my $freeside_gid = scalar(getgrnam('freeside'))
    or die "can't find freeside group\n";
  $) = $freeside_gid;
  $( = $freeside_gid;
  #if freebsd can't setuid(), presumably it can't setgid() either.  grr fleabsd
  ($(,$)) = ($),$();
  $) = $freeside_gid;
  
  $> = $FS::UID::freeside_uid;
  $< = $FS::UID::freeside_uid;
  #freebsd is sofa king broken, won't setuid()
  ($<,$>) = ($>,$<);
  $> = $FS::UID::freeside_uid;
}

sub daemonize2 {
  open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
  setsid                    or die "Can't start a new session: $!";
  open STDERR, '>&STDOUT'   or die "Can't dup stdout: $!";

  $SIG{__DIE__} = \&_die;
  $SIG{__WARN__} = \&_logmsg;

  warn "$me starting\n";
}

sub sigint  { $sigint; }
sub sigterm { $sigterm; }

sub logfile { $logfile = shift; } #_logmsg('test'); }

sub myexit {
  unlink $pid_file if -e $pid_file;
  exit;  
}

sub _die {
  die @_ if $^S; # $^S = 1 during an eval(), don't break exception handling
  my $msg = shift;
  unlink $pid_file if -e $pid_file;
  _logmsg($msg);
}

sub _logmsg {
  chomp( my $msg = shift );
  my $log = new IO::File ">>$logfile";
  flock($log, LOCK_EX);
  seek($log, 0, 2);
  print $log "[". time2str("%a %b %e %T %Y",time). "] [$$] $msg\n";
  flock($log, LOCK_UN);
  close $log;
}

1;
