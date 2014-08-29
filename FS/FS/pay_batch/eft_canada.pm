package FS::pay_batch::eft_canada;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use FS::Record 'qsearch';
use FS::Conf;
use FS::cust_pay_batch;
use Date::Format 'time2str';
use Time::Local 'timelocal';

my $conf;
my $origid;

$name = 'eft_canada';

%import_info = ( filetype  => 'NONE' ); # see FS/bin/freeside-eftca-download

my ($trans_code, $process_date);

#ref http://gocanada.about.com/od/canadatravelplanner/a/canada_holidays.htm
my %holiday_yearly = (
   1 => { map {$_=>1}  1 }, #new year's
  11 => { map {$_=>1} 11 }, #remembrance day
  12 => { map {$_=>1} 25 }, #christmas
  12 => { map {$_=>1} 26 }, #boxing day
);
my %holiday = (
  2013 => {  2 => { map {$_=>1} 18 }, #family day
             3 => { map {$_=>1} 29 }, #good friday
             4 => { map {$_=>1}  1 }, #easter monday
             5 => { map {$_=>1} 20 }, #victoria day
             7 => { map {$_=>1}  1 }, #canada day
             8 => { map {$_=>1}  5 }, #First Monday of August Civic Holiday
             9 => { map {$_=>1}  2 }, #labour day
            10 => { map {$_=>1} 14 }, #thanksgiving
          },
  2014 => {  2 => { map {$_=>1} 17 }, #family day
             4 => { map {$_=>1} 18 }, #good friday
             4 => { map {$_=>1} 21 }, #easter monday
             5 => { map {$_=>1} 19 }, #victoria day
             7 => { map {$_=>1}  1 }, #canada day
             8 => { map {$_=>1}  4 }, #First Monday of August Civic Holiday
             9 => { map {$_=>1}  1 }, #labour day
            10 => { map {$_=>1} 13 }, #thanksgiving
          },
  2015 => {  2 => { map {$_=>1} 16 }, #family day
             4 => { map {$_=>1}  3 }, #good friday
             4 => { map {$_=>1}  6 }, #easter monday
             5 => { map {$_=>1} 18 }, #victoria day
             7 => { map {$_=>1}  1 }, #canada day
             8 => { map {$_=>1}  3 }, #First Monday of August Civic Holiday
             9 => { map {$_=>1}  7 }, #labour day
            10 => { map {$_=>1} 12 }, #thanksgiving
          },
);

%export_info = (

  init => sub {
    my $conf = shift;
    my $agentnum = shift;
    my @config;
    if ( $conf->exists('batch-spoolagent') ) {
      @config = $conf->config('batchconfig-eft_canada', $agentnum);
    } else {
      @config = $conf->config('batchconfig-eft_canada');
    }
    # SFTP login, password, trans code, delay time
    ($trans_code) = $config[2];

    $process_date = time2str('%D', process_date($conf, $agentnum));
  },

  delimiter => '', # avoid blank lines for header/footer

  # EFT Upload Specification for .CSV Files, Rev. 2.0
  # not a true CSV format--strings aren't quoted, so be careful
  row => sub {
    my ($cust_pay_batch, $pay_batch) = @_;
    my @fields;
    # company + empty or first + last
    my $company = sprintf('%.64s', $cust_pay_batch->cust_main->company);
    if ( $company ) {
      push @fields, $company, ''
    }
    else {
      push @fields, map { sprintf('%.64s', $_) } 
        $cust_pay_batch->first, $cust_pay_batch->last;
    }
    my ($account, $aba) = split('@', $cust_pay_batch->payinfo);
    my($bankno, $branch);
    if ( $aba =~ /^0(\d{3})(\d{5})$/ ) { # standard format for Canadian bank ID
      ($bankno, $branch) = ( $1, $2 );
    } elsif ( $aba =~ /^(\d{5})\.(\d{3})$/ ) { #how we store branches
      ($branch, $bankno) = ( $1, $2 );
    } else {
      die "invalid branch/routing number '$aba'\n";
    }
    push @fields, sprintf('%05s', $branch),
                  sprintf('%03s', $bankno),
                  $account,
                  sprintf('%.02f', $cust_pay_batch->amount);
    # DB = debit
    push @fields, 'DB', $trans_code, $process_date;
    push @fields, $cust_pay_batch->paybatchnum; # reference
    # strip illegal characters that might occur in customer name
    s/[,|']//g foreach @fields; # better substitution for these?
    return join(',', @fields) . "\n";
  },

);

sub download_note { # is a class method
  my $class = shift;
  my $pay_batch = shift;
  my $conf = FS::Conf->new;
  my $agentnum = $pay_batch->agentnum;
  my $tomorrow = (localtime(time))[2] >= 10;
  my $process_date = process_date($conf, $agentnum);
  my $upload_date = $process_date - 86400;
  my $date_format = $conf->config('date_format') || '%D';

  my $note = '';
  if ( $process_date - time < 86400*2 ) {
    $note = 'Upload this file before 11:00 AM '. 
            ($tomorrow ? 'tomorrow' : 'today') .
            ' (' . time2str($date_format, $upload_date) . '). ';
  } else {
    $note = 'Upload this file before 11:00 AM on '.
      time2str($date_format, $upload_date) . '. ';
  }
  $note .= 'Payments will be processed on '.
    time2str($date_format, $process_date) . '.';

  $note;
}

sub process_date {
  my ($conf, $agentnum) = @_;
  my @config;
  if ( $conf->exists('batch-spoolagent') ) {
    @config = $conf->config('batchconfig-eft_canada', $agentnum);
  } else {
    @config = $conf->config('batchconfig-eft_canada');
  }

  my $process_delay = $config[3] || 1;

  if ( (localtime(time))[2] >= 10 and $process_delay == 1 ) {
    # If downloading the batch after 10:00 local time, it likely won't make
    # the cutoff for next-day turnaround, and EFT will reject it.
    $process_delay++;
  }

  my $pt = time + ($process_delay * 86400);
  my @lt = localtime($pt);
  while (    $lt[6] == 0 #Sunday
          || $lt[6] == 6 #Saturday
          || $holiday_yearly{ $lt[4]+1 }{ $lt[3] }
          || $holiday{ $lt[5]+1900 }{ $lt[4]+1 }{ $lt[3] }
        )
  {
    $pt += 86400;
    @lt = localtime($pt);
  }

  $pt;
}

1;
