package FS::Cron::upload;

use strict;
use vars qw( @ISA @EXPORT_OK $me $DEBUG );
use Exporter;
use Date::Format;
use FS::UID qw(dbh);
use FS::Record qw( qsearch qsearchs );
use FS::Conf;
use FS::queue;
use FS::agent;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use HTTP::Response;
use Net::FTP;

@ISA = qw( Exporter );
@EXPORT_OK = qw ( upload );
$DEBUG = 0;
$me = '[FS::Cron::upload]';

#freeside-daily %opt:
#  -v: enable debugging
#  -l: debugging level
#  -m: Experimental multi-process mode uses the job queue for multi-process and/or multi-machine billing.
#  -r: Multi-process mode dry run option
#  -a: Only process customers with the specified agentnum


sub upload {
  my %opt = @_;

  my $debug = 0;
  $debug = 1 if $opt{'v'};
  $debug = $opt{'l'} if $opt{'l'};

  local $DEBUG = $debug if $debug;

  warn "$me upload called\n" if $DEBUG;

  my @tasks;

  my $date =  time2str('%Y%m%d%H%M%S', $^T); # more?

  my $conf = new FS::Conf;

  my @agents = $opt{'a'} ? FS::agent->by_key($opt{'a'}) : qsearch('agent', {});

  if ( $conf->exists('cust_bill-ftp_spool') ) {
    my $url = $conf->config('cust_bill-ftpdir');
    $url = "/$url" unless $url =~ m[^/];
    $url = 'ftp://' . $conf->config('cust_bill-ftpserver') . $url;

    my $format = $conf->config('cust_bill-ftpformat');
    my $username = $conf->config('cust_bill-ftpusername');
    my $password = $conf->config('cust_bill-ftppassword');

    my %task = (
      'date'      => $date,
      'l'         => $opt{'l'},
      'm'         => $opt{'m'},
      'v'         => $opt{'v'},
      'username'  => $username,
      'password'  => $password,
      'url'       => $url,
      'format'    => $format,
    );

    if ( $conf->exists('cust_bill-spoolagent') ) {
      # then push each agent's spool separately
      foreach ( @agents ) {
        push @tasks, { %task, 'agentnum' => $_->agentnum };
      }
    }
    elsif ( $opt{'a'} ) {
      warn "Per-agent processing, but cust_bill-spoolagent is not enabled.\nSkipped invoice upload.\n";
    }
    else {
      push @tasks, \%task;
    }
  }

  else { #check each agent for billco upload settings

    my %task = (
      'date'      => $date,
      'l'         => $opt{'l'},
      'm'         => $opt{'m'},
      'v'         => $opt{'v'},
    );

    foreach (@agents) {
      my $agentnum = $_->agentnum;

      if ( $conf->config( 'billco-username', $agentnum, 1 ) ) {
        my $username = $conf->config('billco-username', $agentnum, 1);
        my $password = $conf->config('billco-password', $agentnum, 1);
        my $clicode  = $conf->config('billco-clicode',  $agentnum, 1);
        my $url      = $conf->config('billco-url',      $agentnum);
        push @tasks, {
          %task,
          'agentnum' => $agentnum,
          'username' => $username,
          'password' => $password,
          'url'      => $url,
          'clicode'  => $clicode,
          'format'   => 'billco',
        };
      }
    } # foreach @agents

  } #!if cust_bill-ftp_spool

  foreach (@tasks) {

    my $agentnum = $_->{agentnum};

    if ( $opt{'m'} ) {

      if ( $opt{'r'} ) {
        warn "DRY RUN: would add agent $agentnum for queued upload\n";
      } else {
        my $queue = new FS::queue {
          'job'      => 'FS::Cron::upload::spool_upload',
        };
        my $error = $queue->insert( %$_ );
      }

    } else {

      eval { spool_upload(%$_) };
      warn "spool_upload failed: $@\n"
        if $@;

    }

  }

}

sub spool_upload {
  my %opt = @_;

  warn "$me spool_upload called\n" if $DEBUG;
  my $conf = new FS::Conf;
  my $dir = '%%%FREESIDE_EXPORT%%%/export.'. $FS::UID::datasrc. '/cust_bill';

  my $agentnum = $opt{agentnum} or die "no agentnum provided\n";
  my $url      = $opt{url} or die "no url for agent $agentnum\n";
  $url =~ s/^\s+//; $url =~ s/\s+$//;

  my $username = $opt{username} or die "no username for agent $agentnum\n";
  my $password = $opt{password} or die "no password for agent $agentnum\n";

  die "no date provided\n" unless $opt{date};

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $agent = qsearchs( 'agent', { agentnum => $agentnum } )
    or die "no such agent: $agentnum";
  $agent->select_for_update; #mutex 

  if ( $opt{'format'} eq 'billco' ) {

    my $zipfile  = "$dir/agentnum$agentnum-$opt{date}.zip";

    unless ( -f "$dir/agentnum$agentnum-header.csv" ||
             -f "$dir/agentnum$agentnum-detail.csv" )
    {
      warn "$me neither $dir/agentnum$agentnum-header.csv nor ".
           "$dir/agentnum$agentnum-detail.csv found\n" if $DEBUG;
      $dbh->commit or die $dbh->errstr if $oldAutoCommit;
      return;
    }

    # a better way?
    if ($opt{m}) {
      my $sql = "SELECT count(*) FROM queue LEFT JOIN cust_main USING(custnum) ".
        "WHERE queue.job='FS::cust_main::queued_bill' AND cust_main.agentnum = ?";
      my $sth = $dbh->prepare($sql) or die $dbh->errstr;
      while (1) {
        $sth->execute( $agentnum )
          or die "Unexpected error executing statement $sql: ". $sth->errstr;
        last if $sth->fetchrow_arrayref->[0];
        sleep 300;
      }
    }

    foreach ( qw ( header detail ) ) {
      rename "$dir/agentnum$agentnum-$_.csv",
             "$dir/agentnum$agentnum-$opt{date}-$_.csv";
    }

    my $command = "cd $dir; zip $zipfile ".
                  "agentnum$agentnum-$opt{date}-header.csv ".
                  "agentnum$agentnum-$opt{date}-detail.csv";

    system($command) and die "$command failed\n";

    unlink "agentnum$agentnum-$opt{date}-header.csv",
           "agentnum$agentnum-$opt{date}-detail.csv";

    if ( $url =~ /^http/i ) {

      my $ua = new LWP::UserAgent;
      my $res = $ua->request( POST( $url,
                                    'Content_Type' => 'form-data',
                                    'Content' => [ 'username' => $username,
                                                   'pass'     => $password,
                                                   'custid'   => $username,
                                                   'clicode'  => $opt{clicode},
                                                   'file1'    => [ $zipfile ],
                                                 ],
                                  )
                            );

      die "upload failed: ". $res->status_line. "\n"
        unless $res->is_success;

    } elsif ( $url =~ /^ftp:\/\/([\w\.]+)(\/.*)$/i ) {

      my($hostname, $path) = ($1, $2);

      my $ftp = new Net::FTP($hostname)
        or die "can't connect to $hostname: $@\n";
      $ftp->login($username, $password)
        or die "can't login to $hostname: ". $ftp->message."\n";
      unless ( $ftp->cwd($path) ) {
        my $msg = "can't cd $path on $hostname: ". $ftp->message. "\n";
        ( $path eq '/' ) ? warn $msg : die $msg;
      }
      $ftp->binary
        or die "can't set binary mode on $hostname\n";

      $ftp->put($zipfile)
        or die "can't put $zipfile: ". $ftp->message. "\n";

      $ftp->quit;

    } else {
      die "unknown scheme in URL $url\n";
    }

  } else { #$opt{format} ne 'billco'

    my $date = $opt{date};
    my $file = $opt{agentnum} ? "agentnum$opt{agentnum}" : 'spool'; #.csv
    unless ( -f "$dir/$file.csv" ) {
      warn "$me $dir/$file.csv not found\n" if $DEBUG;
      $dbh->commit or die $dbh->errstr if $oldAutoCommit;
      return;
    }
    rename "$dir/$file.csv", "$dir/$file-$date.csv";

    #ftp only for now
    if ( $url =~ m{^ftp://([\w\.]+)(/.*)$}i ) {

      my ($hostname, $path) = ($1, $2);
      my $ftp = new Net::FTP ($hostname)
        or die "can't connect to $hostname: $@\n";
      $ftp->login($username, $password)
        or die "can't login to $hostname: ".$ftp->message."\n";
      unless ( $ftp->cwd($path) ) {
        my $msg = "can't cd $path on $hostname: ".$ftp->message."\n";
        ( $path eq '/' ) ? warn $msg : die $msg;
      }
      chdir($dir);
      $ftp->put("$file-$date.csv")
        or die "can't put $file-$date.csv: ".$ftp->message."\n";
      $ftp->quit;

    } else {
      die "malformed FTP URL $url\n";
    }
  } #opt{format}

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

1;
