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

  my $conf = new FS::Conf;
  my @agent = grep { $conf->config( 'billco-username', $_->agentnum, 1 ) }
              grep { $conf->config( 'billco-password', $_->agentnum, 1 ) }
              qsearch( 'agent', {} );

  my $date =  time2str('%Y%m%d%H%M%S', $^T); # more?

  @agent = grep { $_ == $opt{'a'} } @agent if $opt{'a'};

  foreach my $agent ( @agent ) {

    my $agentnum = $agent->agentnum;

    if ( $opt{'m'} ) {

      if ( $opt{'r'} ) {
        warn "DRY RUN: would add agent $agentnum for queued upload\n";
      } else {

        my $queue = new FS::queue {
          'job'      => 'FS::Cron::upload::billco_upload',
        };
        my $error = $queue->insert(
                                    'agentnum' => $agentnum,
                                    'date'     => $date,
                                    'l'        => $opt{'l'} || '',
                                    'm'        => $opt{'m'} || '',
                                    'v'        => $opt{'v'} || '',
                                  );

      }

    } else {

      eval "&billco_upload( 'agentnum' => $agentnum, 'date' => $date );";
      warn "billco_upload failed: $@\n"
        if ( $@ );

    }

  }

}

sub billco_upload {
  my %opt = @_;

  warn "$me billco_upload called\n" if $DEBUG;
  my $conf = new FS::Conf;
  my $dir = '%%%FREESIDE_EXPORT%%%/export.'. $FS::UID::datasrc. '/cust_bill';

  my $agentnum = $opt{agentnum} or die "no agentnum provided\n";
  my $url      = $conf->config( 'billco-url', $agentnum )
    or die "no url for agent $agentnum\n";
  my $username = $conf->config( 'billco-username', $agentnum, 1 )
    or die "no username for agent $agentnum\n";
  my $password = $conf->config( 'billco-password', $agentnum, 1 )
    or die "no password for agent $agentnum\n";
  my $clicode  = $conf->config( 'billco-clicode', $agentnum )
    or die "no clicode for agent $agentnum\n";

  die "no date provided\n" unless $opt{date};
  my $zipfile  = "$dir/agentnum$agentnum-$opt{date}.zip";

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
      last if $sth->fetchow_arrayref->[0];
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
                                                 'clicode'  => $clicode,
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
    $ftp->cwd($path)
      or die "can't cd $path on $hostname: ". $ftp->message. "\n";
    $ftp->binary
      or die "can't set binary mode on $hostname\n";

    $ftp->put($zipfile)
      or die "can't put $zipfile: ". $ftp->message. "\n";

    $ftp->quit;

  } else {
    die "unknown scheme in URL $url\n";
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

1;
