package FS::pay_batch::td_eft1464;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Date::Format 'time2str';
use FS::Conf;
use FS::Record qw(qsearch);

=head1 NAME

td_eft1464 - TD Commercial Banking EFT1464 format

=head1 CONFIGURATION

The Freeside option 'batchconfig-td_eft1464' must be set 
with the following values on separate lines:

=over 4

=item Originator ID

=item TD Datacenter Location

00400 - Vancouver
00410 - Montreal
00420 - Toronto
00430 - Halifax
00470 - Winnipeg
00490 - Calgary

=item Short Name

=item Long Name

=item Returned Payment Branch (5 digits)

=item Returned Payment Account

=item Transaction Type Code - defaults to "437" (Internet access)

=back

=cut

my $conf;
my %opt;
my $i;

$name = 'td_eft1464';
# TD Bank EFT 1464 Byte format

%import_info = ( filetype => 'NONE' ); 
# just to suppress warning; importing this format is a fatal error

%export_info = (
  delimiter => '',
  init => sub {
    $conf = shift;
    @opt{
      'origid',
      'datacenter',
      'shortname',
      'longname',
      'retbranch',
      'retacct',
      'cpacode',
    } = $conf->config("batchconfig-td_eft1464");
    $opt{'origid'} = sprintf('%-10.10s', $opt{'origid'});
    $opt{'shortname'} = sprintf('%-15.15s', $opt{'shortname'});
    $opt{'longname'} = sprintf('%-30.30s', $opt{'longname'});
    $opt{'retbranch'} = '0004'.sprintf('%5.5s',$opt{'retbranch'});
    $opt{'retacct'} = sprintf('%-11.11s', $opt{'retacct'}). ' ';
    $i = 1;
  },
  header => sub { 
    my $pay_batch = shift;
    my @cust_pay_batch = @{(shift)};
    my $time = $pay_batch->download || time;
    my $now = sprintf("%03u%03u", 
      (localtime(time))[5] % 100,#year since 1900
      (localtime(time))[7]+1);#day of year

    # Request settlement the next day
    my $duedate = time+86400;
    $opt{'due'} = sprintf("%03u%03u",
      (localtime($duedate))[5] % 100,
      (localtime($duedate))[7]+1);

    $opt{'fcn'} = 
      sprintf('%04u', ($pay_batch->batchnum % 9999)+1), # file creation number
    join('',
      'A', #record type
      sprintf('%09u', 1), #record number
      $opt{'origid'},
      $opt{'fcn'},
      $now,
      $opt{'datacenter'},
      ' ' x 1429, #filler
    );
  },
  row => sub {
    my ($cust_pay_batch, $pay_batch) = @_;
    my ($account, $aba) = split('@', $cust_pay_batch->payinfo);
    $i++;
    # The 1464 byte format supports up to 5 payments per line,
    # but we're only going to send 1.
    my $control = join('',
      'D',                  # for 'debit'
      sprintf("%09u", $i),  #record number
      $opt{'origid'},
      $opt{'fcn'},
    );
    my $payment = join('',
      $opt{'cpacode'} || 437, # CPA code, defaults to "Internet access"
      sprintf('%010.0f', $cust_pay_batch->amount*100),
      $opt{'due'}, #due date...? XXX
      sprintf('%09u', $aba),
      sprintf('%-12.12s', $account),
      '0' x 22,
      '0' x 3,
      $opt{'shortname'},
      sprintf('%-30.30s', 
        join(' ',
          $cust_pay_batch->first, $cust_pay_batch->last)
      ),
      $opt{'longname'},
      $opt{'origid'},
      sprintf('%-19.19s', $cust_pay_batch->paybatchnum), # originator reference num
      $opt{'retbranch'},
      $opt{'retacct'}, 
      ' ' x 15,
      ' ' x 22,
      ' ' x 2,
      '0' x 11,
    );
    return sprintf('%-1464s',$control . $payment) ;
  },
  footer => sub {
    my ($pay_batch, $batchcount, $batchtotal) = @_;
    join('',
      'Z',
      sprintf('%09u', $batchcount + 2),
      $opt{'origid'}, 
      $opt{'fcn'},
      sprintf('%014.0f', $batchtotal*100), # total of debit txns
      sprintf('%08u', $batchcount), # number of debit txns
      '0' x 14, # total of credit txns
      '0' x 8, # total of credit txns
      ' ' x 1396,
    )
  },
);

1;

