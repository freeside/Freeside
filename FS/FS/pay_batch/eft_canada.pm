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

%export_info = (
  init => sub {
    my $conf = shift;
    my @config = $conf->config('batchconfig-eft_canada'); 
    # SFTP login, password, trans code, delay time
    my $process_delay;
    ($trans_code, $process_delay) = @config[2,3];
    $process_delay ||= 1; # days
    $process_date = time2str('%D', time + ($process_delay * 86400));
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
                  sprintf('%012s', $account),
                  sprintf('%.02f', $cust_pay_batch->amount);
    # DB = debit
    push @fields, 'DB', $trans_code, $process_date;
    push @fields, $cust_pay_batch->paybatchnum; # reference
    # strip illegal characters that might occur in customer name
    s/[,|']//g foreach @fields; # better substitution for these?
    return join(',', @fields) . "\n";
  },

);

1;
