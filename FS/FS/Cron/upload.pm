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
use FS::Misc qw( send_email ); #for bridgestone
use FS::ftp_target;
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

  my %task = (
    'date'      => $date,
    'l'         => $opt{'l'},
    'm'         => $opt{'m'},
    'v'         => $opt{'v'},
  );

  my @agentnums = ('', map {$_->agentnum} @agents);

  foreach my $target (qsearch('ftp_target', {})) {
    # We don't know here if it's spooled on a per-agent basis or not.
    # (It could even be both, via different events.)  So queue up an 
    # upload for each agent, plus one with null agentnum, and we'll 
    # upload as many files as we find.
    foreach my $a (@agentnums) {
      push @tasks, {
        %task,
        'agentnum'  => $a,
        'targetnum' => $target->targetnum,
        'handling'  => $target->handling,
      };
    }
  }

  # deprecated billco method
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
        'handling' => 'billco',
      };
    }
  } # foreach @agents

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

  my $date = $opt{date} or die "no date provided\n";

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $agentnum = $opt{agentnum};
  my $agent;
  if ( $agentnum ) {
    $agent = qsearchs( 'agent', { agentnum => $agentnum } )
      or die "no such agent: $agentnum";
    $agent->select_for_update; #mutex 
  }

  if ( $opt{'handling'} eq 'billco' ) {

    my $file = "agentnum$agentnum";
    my $zipfile  = "$dir/$file-$date.zip";

    unless ( -f "$dir/$file-header.csv" ||
             -f "$dir/$file-detail.csv" )
    {
      warn "$me neither $dir/$file-header.csv nor ".
           "$dir/$file-detail.csv found\n" if $DEBUG > 1;
      $dbh->commit or die $dbh->errstr if $oldAutoCommit;
      return;
    }

    my $url      = $opt{url} or die "no url for agent $agentnum\n";
    $url =~ s/^\s+//; $url =~ s/\s+$//;

    my $username = $opt{username} or die "no username for agent $agentnum\n";
    my $password = $opt{password} or die "no password for agent $agentnum\n";

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
      rename "$dir/$file-$_.csv",
             "$dir/$file-$date-$_.csv";
    }

    my $command = "cd $dir; zip $zipfile ".
                  "$file-$date-header.csv ".
                  "$file-$date-detail.csv";

    system($command) and die "$command failed\n";

    unlink "$file-$date-header.csv",
           "$file-$date-detail.csv";

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

      my $ftp = new Net::FTP($hostname, Passive=>1)
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

  }
  else { #not billco

    my $targetnum = $opt{targetnum};
    my $ftp_target = FS::ftp_target->by_key($targetnum)
      or die "FTP target $targetnum not found\n";

    $dir .= "/target$targetnum";
    chdir($dir);

    my $file  = $agentnum ? "agentnum$agentnum" : 'spool'; #.csv

    unless ( -f "$dir/$file.csv" ) {
      warn "$me $dir/$file.csv not found\n" if $DEBUG > 1;
      $dbh->commit or die $dbh->errstr if $oldAutoCommit;
      return;
    }

    rename "$dir/$file.csv", "$dir/$file-$date.csv";

    if ( $opt{'handling'} eq 'bridgestone' ) {

      my $prefix = $conf->config('bridgestone-prefix', $agentnum);
      unless ( $prefix ) {
        warn "$me agent $agentnum has no bridgestone-prefix, skipped\n";
        $dbh->commit or die $dbh->errstr if $oldAutoCommit;
        return;
      }

      my $seq = $conf->config('bridgestone-batch_counter', $agentnum) || 1;

      # extract zip code
      join(' ',$conf->config('company_address', $agentnum)) =~ 
        /(\d{5}(\-\d{4})?)\s*$/;
      my $ourzip = $1 || ''; #could be an explicit option if really needed
      $ourzip  =~ s/\D//;
      my $newfile = sprintf('%s_%s_%0.6d.dat', 
                            $prefix,
                            time2str('%Y%m%d', time),
                            $seq);
      warn "copying spool to $newfile\n" if $DEBUG;

      my ($in, $out);
      open $in, '<', "$dir/$file-$date.csv" 
        or die "unable to read $file-$date.csv\n";
      open $out, '>', "$dir/$newfile" or die "unable to write $newfile\n";
      #header--not sure how much of this generalizes at all
      my $head = sprintf(
        "%-6s%-4s%-27s%-6s%0.6d%-5s%-9s%-9s%-7s%0.8d%-7s%0.6d\n",
        ' COMP:', 'VISP', '', ',SEQ#:', $seq, ',ZIP:', $ourzip, ',VERS:1.1',
        ',RUNDT:', time2str('%m%d%Y', $^T),
        ',RUNTM:', time2str('%H%M%S', $^T),
      );
      warn "HEADER: $head" if $DEBUG;
      print $out $head;

      my $rows = 0;
      while( <$in> ) {
        print $out $_;
        $rows++;
      }

      #trailer
      my $trail = sprintf(
        "%-6s%-4s%-27s%-6s%0.6d%-7s%0.9d%-9s%0.9d\n",
        ' COMP:', 'VISP', '', ',SEQ:', $seq,
        ',LINES:', $rows+2, ',LETTERS:', $rows,
      );
      warn "TRAILER: $trail" if $DEBUG;
      print $out $trail;

      close $in;
      close $out;

      my $zipfile = sprintf('%s_%0.6d.zip', $prefix, $seq);
      my $command = "cd $dir; zip $zipfile $newfile";
      warn "compressing to $zipfile\n$command\n" if $DEBUG;
      system($command) and die "$command failed\n";

      my $connection = $ftp_target->connect; # dies on error
      $connection->put($zipfile);

      my $template = join("\n",$conf->config('bridgestone-confirm_template'));
      if ( $template ) {
        my $tmpl_obj = Text::Template->new(
          TYPE => 'STRING', SOURCE => $template
        );
        my $content = $tmpl_obj->fill_in( HASH =>
          {
            zipfile => $zipfile,
            prefix  => $prefix,
            seq     => $seq,
            rows    => $rows,
          }
        );
        my ($head, $body) = split("\n\n", $content, 2);
        $head =~ /^subject:\s*(.*)$/im;
        my $subject = $1;

        $head =~ /^to:\s*(.*)$/im;
        my $to = $1;

        send_email(
          to      => $to,
          from    => $conf->config('invoice_from', $agentnum),
          subject => $subject,
          body    => $body,
        );
      } else { #!$template
        warn "$me agent $agentnum has no bridgestone-confirm_template, no email sent\n";
      }

      $seq++;
      warn "setting batch counter to $seq\n" if $DEBUG;
      $conf->set('bridgestone-batch_counter', $seq, $agentnum);

    } else { # not bridgestone

      # this is the usual case

      my $connection = $ftp_target->connect; # dies on error
      $connection->put("$file-$date.csv");

    }

  } #opt{handling}

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

1;
