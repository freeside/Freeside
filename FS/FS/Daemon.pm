package FS::Daemon;

use vars qw( @ISA @EXPORT_OK );
use vars qw( $pid_dir $me $pid_file $sigint $sigterm $NOSIG $logfile );
use Exporter;
use Fcntl qw(:flock);
use POSIX qw(setsid);
use IO::File;
use File::Basename;
use File::Slurp qw(slurp);
use Date::Format;
use FS::UID qw( forksuidsetup );

#this is a simple refactoring of the stuff from freeside-queued, just to
#avoid duplicate code.  eventually this should use something from CPAN.

@ISA = qw(Exporter);
@EXPORT_OK = qw(
  daemonize1 drop_root daemonize2 myexit logfile sigint sigterm
  daemon_fork daemon_wait daemon_reconnect
);
%EXPORT_TAGS = ( 'all' => [ @EXPORT_OK ] );

$pid_dir = '/var/run';

$NOSIG = 0;
$PID_NEWSTYLE = 0;

our $MAX_KIDS = 10; # for daemon_fork
our $kids = 0;
our %kids;

sub daemonize1 {
  $me = shift;

  $pid_file = $pid_dir;
  if ( $PID_NEWSTYLE ) {
    $pid_file .= '/freeside';
    mkdir $pid_file unless -d $pid_file;
    chown $FS::UID::freeside_uid, -1, $pid_file;
  }
  $pid_file .= "/$me";
  $pid_file .= '.'.shift if scalar(@_);
  $pid_file .= '.pid';

  chdir "/" or die "Can't chdir to /: $!";
  open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
  defined(my $pid = fork) or die "Can't fork: $!";
  if ( $pid ) {
    print "$me started with pid $pid\n"; #logging to $log_file\n";
    exit unless $pid_file;
    my $pidfh = new IO::File ">$pid_file" or exit;
    chown $FS::UID::freeside_uid, -1, $pid_file;
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

  # set the logfile sensibly
  if (!$logfile) {
    my $logname = $me;
    $logname =~ s/^freeside-//;
    logfile("%%%FREESIDE_LOG%%%/$logname-log.$FS::UID::datasrc");
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
  chomp( my $pid = slurp($pid_file) );
  unlink $pid_file if -e $pid_file && $$ == $pid;
  exit;  
}

sub _die {
  die @_ if $^S; # $^S = 1 during an eval(), don't break exception handling
  my $msg = shift;

  chomp( my $pid = slurp($pid_file) );
  unlink $pid_file if -e $pid_file && $$ == $pid;

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

=item daemon_fork CODEREF[, ARGS ]

Executes CODEREF in a child process, with its own $FS::UID::dbh handle.  If
the number of child processes is >= $FS::Daemon::MAX_KIDS then this will
block until some of the child processes are finished. ARGS will be passed
to the coderef.

If the fork fails, this will throw an exception containing $!. Otherwise
it returns the PID of the child, like fork() does.

=cut

sub daemon_fork {
  $FS::UID::dbh->{AutoInactiveDestroy} = 1;
  # wait until there's a lane open
  daemon_wait($MAX_KIDS - 1);

  my ($code, @args) = @_;

  my $user = $FS::CurrentUser::CurrentUser->username;

  my $pid = fork;
  if (!defined($pid)) {

    warn "WARNING: can't fork: $!\n";
    die "$!\n";

  } elsif ( $pid > 0 ) {

    $kids{ $pid } = 1;
    $kids++;
    return $pid;

  } else { # kid
    forksuidsetup( $user );
    &{$code}(@args);
    exit;

  }
}

=item daemon_wait [ MAX ]

Waits until there are at most MAX daemon_fork() child processes running,
reaps the ones that are finished, and continues. MAX defaults to zero, i.e.
wait for everything to finish.

=cut

sub daemon_wait {
  my $max = shift || 0;
  while ($kids > $max) {
    foreach my $pid (keys %kids) {
      my $kid = waitpid($pid, WNOHANG);
      if ( $kid > 0 ) {
        $kids--;
        delete $kids{$kid};
      }
    }
    sleep(1);
  }
}

=item daemon_reconnect

Checks whether the database connection is live, and reconnects if not.

=cut

sub daemon_reconnect {
  my $dbh = $FS::UID::dbh;
  unless ($dbh && $dbh->ping) {
    warn "WARNING: connection to database lost, reconnecting...\n";

    eval { $FS::UID::dbh = myconnect(); };

    unless ( !$@ && $FS::UID::dbh && $FS::UID::dbh->ping ) {
      warn "WARNING: still no connection to database, sleeping for retry...\n";
      sleep 10;
      next;
    } else {
      warn "WARNING: reconnected to database\n";
    }
  }
}

1;
