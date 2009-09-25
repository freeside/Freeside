package FS::pay_batch::chase_canada;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Time::Local 'timelocal';
use FS::Conf;

my $conf;
my $origid;

$name = 'csv-chase_canada-E-xactBatch';

%import_info = (
  'filetype'    => 'CSV',
  'fields'      => [
    '',
    '',
    '',
    'paid',
    'auth',
    'payinfo',
    '',
    '',
    'bankcode',
    'bankmess',
    'etgcode',
    'etgmess',
    '',
    'paybatchnum',
    '',
    'result',
  ],
  'hook'        => sub {
    my $hash = shift;
    my $cpb = shift;
    $hash->{'paid'} = sprintf("%.2f", $hash->{'paid'} );
    $hash->{'_date'} = time;
    $hash->{'payinfo'} = $cpb->{'payinfo'}
      if( substr($hash->{'payinfo'}, -4) eq substr($cpb->{'payinfo'}, -4) );
  },
  'approved'    => sub { 
    my $hash = shift;
    $hash->{'etgcode'} eq '00' && $hash->{'result'} eq 'Approved';
  },
  'declined'    => sub { 
    my $hash = shift;
    $hash->{'etgcode'} ne '00' || $hash->{'result'} eq 'Declined';
  },
);

%export_info = (
  init => sub {
    $conf = shift;
    ($origid) = $conf->config("batchconfig-$name");
  },
  header => sub { 
    my $pay_batch = shift;
    sprintf( '$$E-xactBatchFileV1.0$$%s:%03u$$%s',
      sdate($pay_batch->download),
      $pay_batch->batchnum, 
      $origid );
  },
  row => sub {
    my ($cust_pay_batch, $pay_batch) = @_;
    my $payname = $cust_pay_batch->payname;
    $payname =~ tr/",/  /;
                
    join(',', 
      $cust_pay_batch->paybatchnum,
      $cust_pay_batch->custnum,
      $cust_pay_batch->invnum,
      qq!"$payname"!,
      '00',
      $cust_pay_batch->payinfo,
      $cust_pay_batch->amount,
      expdate($cust_pay_batch->exp),
      '',
      ''
    );
  },
  # no footer
);

sub sdate {
  my (@date) = localtime(shift);
  sprintf('%02d/%02d/%02d', $date[5] % 100, $date[4] + 1, $date[3]);
}

sub expdate {
  my $exp = shift;
  $exp =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
  my ($mon, $y) = ($2, $1);
  if($conf->exists('batch-increment_expiration')) {
    my ($curmon, $curyear) = (localtime(time))[4,5];
    $curmon++;
    $curyear -=  100;
    $y++ while $y < $curyear || ($y == $curyear && $mon < $curmon);
  }
  $mon = "0$mon" if $mon =~ /^\d$/;
  $y = "0$y" if $y =~ /^\d$/;
  return "$mon$y";
}

1;
