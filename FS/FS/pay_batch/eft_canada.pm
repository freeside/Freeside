package FS::pay_batch::eft_canada;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use FS::Record 'qsearch';
use FS::Conf;
use FS::cust_pay_batch;
use DateTime;

my $conf;
my $origid;

$name = 'eft_canada';

%import_info = ( filetype  => 'NONE' ); # see FS/bin/freeside-eftca-download

my ($business_trans_code, $personal_trans_code, $trans_code);
my $req_date; # requested process date, in %D format

# use Date::Holidays::CA for this?
#ref http://gocanada.about.com/od/canadatravelplanner/a/canada_holidays.htm
my %holiday_yearly = (
   1 => { map {$_=>1}  1 }, #new year's
  11 => { map {$_=>1} 11 }, #remembrance day
  12 => { map {$_=>1} 25 }, #christmas
  12 => { map {$_=>1} 26 }, #boxing day
);
my %holiday = (
  2015 => {  2 => { map {$_=>1} 16 }, #family day
             4 => { map {$_=>1}  3 }, #good friday
             4 => { map {$_=>1}  6 }, #easter monday
             5 => { map {$_=>1} 18 }, #victoria day
             7 => { map {$_=>1}  1 }, #canada day
             8 => { map {$_=>1}  3 }, #First Monday of August Civic Holiday
             9 => { map {$_=>1}  7 }, #labour day
            10 => { map {$_=>1} 12 }, #thanksgiving
          },
  2016 => {  2 => { map {$_=>1} 15 }, #family day
             3 => { map {$_=>1} 25 }, #good friday
             3 => { map {$_=>1} 28 }, #easter monday
             5 => { map {$_=>1} 23 }, #victoria day
             7 => { map {$_=>1}  1 }, #canada day
             8 => { map {$_=>1}  1 }, #First Monday of August Civic Holiday
             9 => { map {$_=>1}  5 }, #labour day
            10 => { map {$_=>1} 10 }, #thanksgiving
          },
);

sub is_holiday {
  my $dt = shift;
  return 1 if exists( $holiday_yearly{$dt->month} )
          and exists( $holiday_yearly{$dt->month}{$dt->day} );
  return 1 if exists( $holiday{$dt->year} )
          and exists( $holiday{$dt->year}{$dt->month} )
          and exists( $holiday{$dt->year}{$dt->month}{$dt->day} );
  return 0;
}

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
    # SFTP login, password, business and personal trans codes, delay time
    ($business_trans_code) = $config[2];
    ($personal_trans_code) = $config[3];

    my ($process_date) = process_dates($conf, $agentnum);
    $req_date = $process_date->strftime('%D');
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
      push @fields, 'Business';
      push @fields, $company, '';
      $trans_code = $business_trans_code;
    }
    else {
      push @fields, 'Personal';
      push @fields, map { sprintf('%.64s', $_) } 
        $cust_pay_batch->first, $cust_pay_batch->last;
        $trans_code = $personal_trans_code;
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
    push @fields, 'DB', $trans_code, $req_date;
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
  my ($process_date, $upload_date) = process_dates($conf, $agentnum);
  my $date_format = $conf->config('date_format') || '%D';
  my $days_until_upload = $upload_date->delta_days(DateTime->now);

  my $note = '';
  if ( $days_until_upload->days == 0 ) {
    $note = 'Upload this file before 11:00 AM today'. 
            ' (' . $upload_date->strftime($date_format) . '). ';
  } elsif ( $days_until_upload->days == 1 ) {
    $note = 'Upload this file before 11:00 AM tomorrow'. 
            ' (' . $upload_date->strftime($date_format) . '). ';
  } else {
    $note = 'Upload this file before 11:00 AM on '.
      $upload_date->strftime($date_format) . '. ';
  }
  $note .= 'Payments will be processed on '.
    $process_date->strftime($date_format) . '.';

  $note;
}

sub process_dates { # returns both process and upload dates
  my ($conf, $agentnum) = @_;
  my @config;
  if ( $conf->exists('batch-spoolagent') ) {
    @config = $conf->config('batchconfig-eft_canada', $agentnum);
  } else {
    @config = $conf->config('batchconfig-eft_canada');
  }
  
  my $process_delay = $config[4] || 1;

  my $ut = DateTime->now; # the latest time we assume the user
                          # could upload the file
  $ut->truncate(to => 'day')->set_hour(10); # is 10 AM on whatever day
  if ( $ut < DateTime->now ) {
    # then we would submit the file today but it's already too late
    $ut->add(days => 1);
  }
  while (    $ut->day_of_week == 6 # Saturday
          or $ut->day_of_week == 7 # Sunday
          or is_holiday($ut)
        )
  {
    $ut->add(days => 1);
  }
  # $ut is now the latest time that the user can upload the file.

  # that time, plus the process delay, is the _earliest_ process date we can
  # request. if that's on a weekend or holiday, the process date has to be
  # later.

  my $pt = $ut->clone();
  $pt->add(days => $process_delay);
  while (    $pt->day_of_week == 6
          or $pt->day_of_week == 7
          or is_holiday($pt)
        )
  {
    $pt->add(days => 1);
  }

  ($pt, $ut);
}

1;
