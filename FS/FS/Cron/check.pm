package FS::Cron::check;

use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG $FS_RUN $error_msg
             $SELFSERVICE_USER $SELFSERVICE_MACHINES @SELFSERVICE_MACHINES
           );
use Exporter;
use LWP::UserAgent;
use FS::Conf;
use FS::Record qw(qsearch);
use FS::cust_pay_pending;

@ISA = qw( Exporter );
@EXPORT_OK = qw(
  check_queued check_selfservice check_apache check_bop_failures
  alert error_msg
);

$DEBUG = 0;

$FS_RUN = '/var/run';

sub check_queued {
  _check_fsproc('queued');
}

$SELFSERVICE_USER = '%%%SELFSERVICE_USER%%%';

$SELFSERVICE_MACHINES = '%%%SELFSERVICE_MACHINES%%%'; #substituted by Makefile
$SELFSERVICE_MACHINES =~ s/^\s+//;
$SELFSERVICE_MACHINES =~ s/\s+$//;
@SELFSERVICE_MACHINES = split(/\s+/, $SELFSERVICE_MACHINES);
@SELFSERVICE_MACHINES = ()
  if scalar(@SELFSERVICE_MACHINES) == 1
  && $SELFSERVICE_MACHINES[0] eq '%%%'.'SELFSERVICE_MACHINES'.'%%%';

sub check_selfservice {
  foreach my $machine ( @SELFSERVICE_MACHINES ) {
    unless ( _check_fsproc("selfservice-server.$SELFSERVICE_USER.$machine") ) {
      $error_msg = "Self-service daemon not running for $machine";
      return 0;
    }
  }
  return 1;
}

sub _check_fsproc {
  my $arg = shift;
  _check_pidfile( "freeside-$arg.pid" );
}

sub _check_pidfile {
  my $pidfile = shift;
  open(PID, "$FS_RUN/$pidfile") or return 0;
  chomp( my $pid = scalar(<PID>) );
  close PID; # or return 0;

  $pid && kill 0, $pid;
}

sub check_apache {
  my $ua = new LWP::UserAgent;
  $ua->agent("FreesideCronCheck/0.1 " . $ua->agent);

  my $req = new HTTP::Request GET => 'https://localhost/';
  my $res = $ua->request($req);

  return 1 if $res->is_success || $res->status_line =~ /^403/;
  $error_msg = $res->status_line;
  return 0;

}

#and now for something entirely different...
my $num_consecutive_bop_failures = 50;
sub check_bop_failures {

  return 1 if grep { $_->statustext eq 'captured' }
                   qsearch({
                     'table'    => 'cust_pay_pending',
                     'hashref'  => { 'status' => 'done' },
                     'order_by' => 'ORDER BY paypendingnum DESC'.
                                   " LIMIT $num_consecutive_bop_failures",
                   });
  $error_msg = "Last $num_consecutive_bop_failures real-time payments failed";
  return 0;
}

#

sub error_msg {
  $error_msg;
}

sub alert {
  my( $alert, @emails ) = @_;

  my $conf = new FS::Conf;
  my $smtpmachine = $conf->config('smtpmachine');
  my $company_name = $conf->config('company_name');

  foreach my $email (@emails) {
    warn "warning $email about $alert\n" if $DEBUG;

    my $message = <<"__MESSAGE__";
From: support\@freeside.biz
To: $email
Subject: FREESIDE ALERT for $company_name

FREESIDE ALERT: $alert

__MESSAGE__

    my $sender = Email::Send->new({ mailer => 'SMTP' });
    $sender->mailer_args([ Host => $smtpmachine ]);
    $sender->send($message);

  }

}

1;

