package FS::pay_batch::RBC;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Date::Format 'time2str';
use FS::Conf;

my $conf;
my ($client_num, $shortname, $longname, $trans_code, $i);

$name = 'RBC';
# Royal Bank of Canada ACH Direct Payments Service

%import_info = (
  'filetype'    => 'fixed',
  'formatre'    => 
  '^(.).{18}(.{4}).{15}(.{19}).{6}(.{30}).{17}(.{9})(.{18}).{6}(.{14}).{23}(.).{9}$',
  'fields' => [ qw(
    recordtype
    batchnum
    paybatchnum
    custname
    bank
    payinfo
    paid
    status
    ) ],
  'hook' => sub {
      my $hash = shift;
      $hash->{'paid'} = sprintf("%.df", $hash->{'paid'} / 100 );
      $hash->{'_date'} = time;
      $hash->{'payinfo'} = $hash->{'payinfo'} . '@' . $hash->{'bank'};
  },
  'approved'    => sub { 
      my $hash = shift;
      $hash->{'status'} eq ' '
  },
  'declined'    => sub {
      my $hash = shift;
      grep { $hash->{'status'} eq $_ } ('E', 'R', 'U', 'T');
  },
  'end_hook'    => sub {
      my( $hash, $total, $line ) = @_;
      $total = sprintf("%.2f", $total);
      my $batch_total = sprintf("%.2f", substr($line, 140, 18) / 100);
      return "Our total $total does not match bank total $batch_total!"
        if $total != $batch_total;
      '';
  },
  'end_condition' => sub {
      my $hash = shift;
      $hash->{recordtype} == '3'; # Account Trailer Record
  },
);

%export_info = (
  init => sub {
    $conf = shift;
    ($client_num,
     $shortname,
     $longname,
     $trans_code, 
     ) = $conf->config("batchconfig-RBC");
    $i = 1;
  },
  header => sub { 
    my $pay_batch = shift;
    '000001'.
    'A'.
    'HDR'.
    sprintf("%10s", $client_num).
    sprintf("%-30s", $longname).
    sprintf("%04u", $pay_batch->batchnum).
    time2str("%Y%j", $pay_batch->download).
    'CAD'.
    '1'.
    ' ' x 87  # filler/reserved fields
    ;
  },
  row => sub {
    my ($cust_pay_batch, $pay_batch) = @_;
    my ($account, $aba) = split('@', $cust_pay_batch->payinfo);
    $i++;
    sprintf("%06u", $i).
    'D'.
    sprintf("%3s",$trans_code).
    sprintf("%10s",$client_num).
    ' '.
    sprintf("%-19s", $cust_pay_batch->paybatchnum).
    '00'.
    sprintf("%09u", $aba).
    sprintf("%-18s", $account).
    ' '.
    sprintf("%010u",$cust_pay_batch->amount*100).
    '      '.
    time2str("%Y%j", $pay_batch->download).
    sprintf("%-30s", $cust_pay_batch->cust_main->first . ' ' .
                     $cust_pay_batch->cust_main->last).
    'E'. # English
    ' '.
    sprintf("%-15s", $shortname).
    'CAD'.
    ' '.
    'CAN'.
    '    '.
    'N' # no customer optional information follows
    ;
# Note: IAT Address Information and Remittance records are not 
# supported. This means you probably can't process payments 
# destined to U.S. bank accounts.  If you need this feature, contact 
# Freeside Internet Services.
  },
  footer => sub {
    my ($pay_batch, $batchcount, $batchtotal) = @_;
    sprintf("%06u", $i + 1).
    'Z'.
    'TRL'.
    sprintf("%10s", $client_num).
    ' ' x 20 .
    sprintf("%06u", $batchcount).
    sprintf("%014u", $batchtotal*100).
    '00' .
    '000000' . # total number of customer information records
    ' ' x 84
    ;
  },
);

1;

