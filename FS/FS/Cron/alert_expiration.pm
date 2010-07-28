package FS::Cron::alert_expiration;

use vars qw( @ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(qsearch qsearchs);
use FS::Conf;
use FS::cust_main;
use FS::Misc;
use Time::Local;
use Date::Parse qw(str2time);


@ISA = qw( Exporter );
@EXPORT_OK = qw( alert_expiration );

my $warning_time = 30 * 24 * 60 * 60;
my $urgent_time = 15 * 24 * 60 * 60;
my $panic_time = 5 * 24 * 60 * 60;
my $window_time = 24 * 60 * 60;

sub alert_expiration {
  my $conf = new FS::Conf;
  my $smtpmachine = $conf->config('smtpmachine');
  
  my %opt = @_;
  my ($_date) = $opt{'d'} ? str2time($opt{'d'}) : $^T;
  $_date += $opt{'y'} * 86400 if $opt{'y'};
  my ($sec, $min, $hour, $mday, $mon, $year) = (localtime($_date)) [0..5];
  $mon++;

  my $debug = 0;
  $debug = 1 if $opt{'v'};
  $debug = $opt{'l'} if $opt{'l'};

  $FS::cust_main::DEBUG = $debug;

  # Get a list of customers.
 
  my %limit;
  $limit{'agentnum'} = $opt{'a'} if $opt{'a'};
  $limit{'payby'}    = $opt{'p'} if $opt{'p'};

  my @customers;

  if(my @custnums = @ARGV) {
    # We're given an explicit list of custnums, so select those.  Then check against 
    # -a and -p to avoid doing anything unexpected.
    foreach (@custnums) {
      my $customer = FS::cust_main->by_key($_);
      if($customer and (!$opt{'a'} or $customer->agentnum == $opt{'a'})
                   and (!$opt{'p'} or $customer->payby eq $opt{'p'}) ) {
        push @customers, $customer;
      }
    }
  }
  else { # no @ARGV
    @customers = qsearch('cust_main', \%limit);
  }
  return if(!@customers);
  foreach my $customer (@customers) {
    next if !($customer->ncancelled_pkgs); # skip inactive customers
    my $paydate = $customer->paydate;
    next if $paydate =~ /^\s*$/; # skip empty expiration dates
    
    my $custnum = $customer->custnum;
    my $first   = $customer->first;
    my $last    = $customer->last;
    my $company = $customer->company;
    my $payby   = $customer->payby;
    my $payinfo = $customer->payinfo;
    my $daytime = $customer->daytime;
    my $night   = $customer->night;

    my ($paymonth, $payyear) = $customer->paydate_monthyear;
    $paymonth--; # localtime() convention
    $payday = 1; # This is enforced by FS::cust_main::check.
    my $expire_time;
    if($payby eq 'CARD' || $payby eq 'DCRD') {
      # Credit cards expire at the end of the month/year.
      if($paymonth == 11) {
        $payyear++;
        $paymonth = 0;
      } else {
        $paymonth++;
      }
      $expire_time = timelocal(0,0,0,$payday,$paymonth,$payyear) - 1;
    }
    else {
      $expire_time = timelocal(0,0,0,$payday,$paymonth,$payyear);
    }
    
    if (grep { $expire_time < $_date + $_ &&
               $expire_time > $_date + $_ - $window_time } 
               ($warning_time, $urgent_time, $panic_time) ) {
      # Send an expiration notice.
      my $agentnum = $customer->agentnum;
      my $error = '';

      my $msgnum = $conf->config('alerter_msgnum', $agentnum);
      if ( $msgnum ) { # new hotness
        my $msg_template = qsearchs('msg_template', { msgnum => $msgnum } );
        $error = $msg_template->send('cust_main' => $customer);
      }
      else { #!$msgnum, the hard way
        $mail_sender = $conf->config('invoice_from', $agentnum);
        $failure_recipient = $conf->config('invoice_from', $agentnum) 
          || 'postmaster';
       
        my @alerter_template = $conf->config('alerter_template', $agentnum)
          or die 'cannot load config file alerter_template';

        my $alerter = new Text::Template(TYPE   => 'ARRAY',
                                         SOURCE => [ 
                                           map "$_\n", @alerter_template
                                           ])
          or die "can't create Text::Template object: $Text::Template::ERROR";

        $alerter->compile()
          or die "can't compile template: $Text::Template::ERROR";
        
        my @invoicing_list = $customer->invoicing_list;
        my @to_addrs = grep { $_ ne 'POST' } @invoicing_list;
        if(@to_addrs) {
          # Set up template fields.
          my %fill_in;
          $fill_in{$_} = $customer->getfield($_) 
            foreach(qw(first last company));
          $fill_in{'expdate'} = $expire_time;
          $fill_in{'company_name'} = $conf->config('company_name', $agentnum);
          $fill_in{'company_address'} =
            join("\n",$conf->config('company_address',$agentnum))."\n";
          if($payby eq 'CARD' || $payby eq 'DCRD') {
            $fill_in{'payby'} = "credit card (".
              substr($customer->payinfo, 0, 2) . "xxxxxxxxxx" .
              substr($payinfo, -4) . ")";
          }
          elsif($payby eq 'COMP') {
            $fill_in{'payby'} = 'complimentary account';
          }
          else {
            $fill_in{'payby'} = 'current method';
          }
          # Send it already!
          $error = FS::Misc::send_email ( 
            from    =>  $mail_sender,
            to      =>  [ @to_addrs ],
            subject =>  'Billing Arrangement Expiration',
            body    =>  [ $alerter->fill_in( HASH => \%fill_in ) ],
          );
      } 
      else { # if(@to_addrs)
        push @{$agent_failure_body{$customer->agentnum}},
          sprintf(qq{%5d %-32.32s %4s %10s %12s %12s},
            $custnum,
            $first . " " . $last . "   " . $company,
            $payby,
            $paydate,
            $daytime,
            $night );
      }
    } # if($msgnum)
    
# should we die here rather than report failure as below?
    die "can't send expiration alert: $error"
      if $error;
    
    } # if(expired)
  } # foreach(@customers)

  # Failure notification
  foreach my $agentnum (keys %agent_failure_body) {
    $mail_sender = $conf->config('invoice_from', $agentnum)
      if($conf->exists('invoice_from', $agentnum));
    $failure_recipient = $conf->config('invoice_from', $agentnum)
      if($conf->exists('invoice_from', $agentnum));
    my $error = FS::Misc::send_email (
      from    =>  $mail_sender,
      to      =>  $failure_recipient,
      subject =>  'Unnotified Billing Arrangement Expirations',
      body    =>  [ @{$agent_failure_body{$agentnum}} ],
      );
    die "can't send alerter failure email to $failure_recipient: $error"
      if $error;
  }

}

1;
