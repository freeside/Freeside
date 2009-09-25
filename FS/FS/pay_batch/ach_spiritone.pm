package FS::pay_batch::ach_spiritone;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Time::Local 'timelocal';
use FS::Conf;
use File::Temp;

my $conf;
my ($origid, $datacenter, $typecode, $shortname, $longname, $mybank, $myacct);

$name = 'ach-spiritone'; # note spelling

%import_info = (
  'filetype'    => 'CSV',
  'fields'      => [
    '', #name
    'paybatchnum',  
    'aba',
    'payinfo', 
    '', #transaction type
    'paid',
    '', #default transaction type
    '', #default amount
  ],
  'hook'        => sub {
      my $hash = shift;
      $hash->{'_date'} = time;
      $hash->{'payinfo'} = $hash->{'payinfo'} . '@' . $hash->{'aba'};
  },
  'approved'    => sub { 1 },
  'declined'    => sub { 0 },
);

%export_info = (
# This is the simplest case.
  row => sub {
    my ($cust_pay_batch, $pay_batch) = @_;
    my ($account, $aba) = split('@', $cust_pay_batch->payinfo);
    my $payname = $cust_pay_batch->first . ' ' . $cust_pay_batch->last;
    $payname =~ tr/",/  /; 
    qq!"$payname","!.$cust_pay_batch->paybatchnum.
    qq!","$aba","$account","27","!.$cust_pay_batch->amount.
    qq!","27","0.00"!; #"
  },
  autopost => sub {
    my ($pay_batch, $batch) = @_;
    my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
    my $fh = new File::Temp(
      TEMPLATE => 'paybatch.'. $pay_batch->batchnum .'.XXXXXXXX',
      DIR      => $dir,
    ) or return "can't open temp file: $!\n";

    print $fh $batch;
    seek $fh, 0, 0;

    my $error = $pay_batch->import_results( 'filehandle' => $fh,
                                         'format'     => $name,
                                       );
    return $error if $error;
  },
);

1;

