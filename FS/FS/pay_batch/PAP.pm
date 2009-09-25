package FS::pay_batch::PAP;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Time::Local 'timelocal';
use FS::Conf;

my $conf;
my ($origid, $datacenter, $typecode, $shortname, $longname, $mybank, $myacct);

$name = 'PAP';

%import_info = (
  'filetype'    => 'fixed',
  'formatre'    => '^(.).{19}(.{4})(.{3})(.{10})(.{6})(.{9})(.{12}).{110}(.{19}).{71}$',
  'fields'      => [
    'recordtype',
    'batchnum',
    'datacenter',
    'paid',
    '_date',
    'bank',
    'payinfo',
    'paybatchnum',
  ],
  'hook'        => sub {
      my $hash = shift;
      $hash->{'paid'} = sprintf("%.2f", $hash->{'paid'} / 100 );
      my $tmpdate = timelocal( 0,0,1,1,0,substr($hash->{'_date'}, 0, 3)+2000);
      $tmpdate += 86400*(substr($hash->{'_date'}, 3, 3)-1) ;
      $hash->{'_date'} = $tmpdate;
      $hash->{'payinfo'} = $hash->{'payinfo'} . '@' . $hash->{'bank'};
  },
  'approved'    => sub { 1 },
  'declined'    => sub { 0 },
# Why does pay_batch.pm have approved_condition and declined_condition?
# It doesn't even try to handle the case of neither condition being met.
  'end_hook'    => sub {
      my( $hash, $total) = @_;
      $total = sprintf("%.2f", $total);
      my $batch_total = $hash->{'datacenter'}.$hash->{'paid'}.
                        substr($hash->{'_date'},0,1);          # YUCK!
      $batch_total = sprintf("%.2f", $batch_total / 100 );
      return "Our total $total does not match bank total $batch_total!"
        if $total != $batch_total;
      '';
  },
  'end_condition' => sub {
      my $hash = shift;
      $hash->{recordtype} eq 'W';
  },
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
     $myacct) = $conf->config("batchconfig-PAP");
  },
  header => sub { 
    my $pay_batch = shift;
    sprintf( "H%10sD%3s%06u%-15s%09u%-12s%04u%19s\n",
      $origid,
      $typecode,
      cdate($pay_batch->download),
      $shortname,
      $mybank,
      $myacct,
      $pay_batch->batchnum,
      "" )
  },
  row => sub {
    my ($cust_pay_batch, $pay_batch) = @_;
    my ($account, $aba) = split('@', $cust_pay_batch->payinfo);
    sprintf( "D%-23s%06u%-19s%09u%-12s%010.0f\n",
      $cust_pay_batch->payname,
      cdate($pay_batch->download),
      $cust_pay_batch->paybatchnum,
      $aba,
      $account,
      $cust_pay_batch->amount*100 );
  },
  footer => sub {
    my ($pay_batch, $batchcount, $batchtotal) = @_;
    sprintf( "T%08u%014.0f%57s\n",
      $batchcount,
      $batchtotal*100,
      "" );
  },
);

sub cdate {
  my (@date) = localtime(shift);
  sprintf("%02d%02d%02d", $date[3], $date[4] + 1, $date[5] % 100);
}

1;

