package FS::pay_batch::BoM;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Time::Local 'timelocal';
use FS::Conf;

my $conf;
my ($origid, $datacenter, $typecode, $shortname, $longname, $mybank, $myacct);

$name = 'BoM';

%import_info = (
  'filetype'    => 'CSV',
  'fields'      => [],
  'hook'        => sub { die "Can't import BoM" },
  'approved'    => sub { 1 },
  'declined'    => sub { 0 },
);

%export_info = (
  init => sub {
    $conf = shift;
    ($origid,
     $datacenter,
     $typecode, 
     $shortname, 
     $longname, 
     $mybank, 
     $myacct) = $conf->config("batchconfig-BoM");
  },
  header => sub { 
    my $pay_batch = shift;
    sprintf( "A%10s%04u%06u%05u%54s\n", 
      $origid,
      $pay_batch->batchnum,
      jdate($pay_batch->download),
      $datacenter,
      "") .
    sprintf( "XD%03u%06u%-15s%-30s%09u%-12s   \n",
      $typecode,
      jdate($pay_batch->download),
      $shortname,
      $longname,
      $mybank,
      $myacct);
  },
  row => sub {
    my ($cust_pay_batch, $pay_batch) = @_;
    my ($account, $aba) = split('@', $cust_pay_batch->payinfo);
    sprintf( "D%010.0f%09u%-12s%-29s%-19s\n",
      $cust_pay_batch->amount * 100,
      $aba,
      $account,
      $cust_pay_batch->payname,
      $cust_pay_batch->paybatchnum
      );
  },
  footer => sub {
    my ($pay_batch, $batchcount, $batchtotal) = @_;
    sprintf( "YD%08u%014.0f%56s\n", $batchcount, $batchtotal*100, "").
    sprintf( "Z%014u%04u%014u%05u%41s\n", 
      $batchtotal*100, $batchcount, "0", "0", "");
  },
);

sub jdate {
  my (@date) = localtime(shift);
  sprintf("%03d%03d", $date[5] % 100, $date[7] + 1);
}

1;

