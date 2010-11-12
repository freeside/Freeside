package FS::pay_batch::td_canada_trust;

# Formerly known as csv-td_canada_trust-merchant_pc_batch,
# which I'm sure we can all agree is both a terrible name 
# and an illegal Perl identifier.

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Time::Local 'timelocal';
use FS::Conf;

my $conf;
my ($origid, $datacenter, $typecode, $shortname, $longname, $mybank, $myacct);

$name = 'csv-td_canada_trust-merchant_pc_batch';

%import_info = (
  'filetype'    => 'CSV',
  'fields'      => [
    'paybatchnum',  
    'paid',
    '', # card type
    '_date',
    'time',
    'payinfo', 
    '', # expiry date
    '', # auth number
    'type', # transaction type
    'result', # processing result
    '', # terminal ID
  ],
  'hook'        => sub {
      my $hash = shift;
      my $date = $hash->{'_date'};
      my $time = $hash->{'time'};
      $hash->{'paid'} = sprintf("%.2f", $hash->{'paid'} / 100);
      $hash->{'_date'} = timelocal( substr($time, 4, 2),
                                    substr($time, 2, 2),
                                    substr($time, 0, 2),
                                    substr($date, 6, 2),
                                    substr($date, 4, 2)-1,
                                    substr($date, 0, 4)-1900 );
  },
  'approved'    => sub { 
    my $hash = shift;
    $hash->{'type'} eq '0' && $hash->{'result'} == 3
  },
  'declined'    => sub { 
    my $hash = shift;
    $hash->{'type'} eq '0' && ( $hash->{'result'} == 4
                            ||  $hash->{'result'} == 5 )
  },
  'end_condition' => sub {
    my $hash = shift;
    $hash->{'type'} eq '0BC';
  },
  'end_hook' => sub {
    my ($hash, $total) = @_;
    $total = sprintf("%.2f", $total);
    my $batch_total = sprintf("%.2f", $hash->{'paybatchnum'} / 100);
    return "Our total $total does not match bank total $batch_total!"
      if $total != $batch_total;
  },
);

%export_info = (
  init => sub { 
    $conf = shift; 
  },
  # no header
  row => sub {
    my ($cust_pay_batch, $pay_batch) = @_;

    return join(',', 
      '',
      '',
      '',
      '', 
      $cust_pay_batch->payinfo,
      $cust_pay_batch->expmmyy,
      $cust_pay_batch->amount,
      $cust_pay_batch->paybatchnum
      );
  },
# no footer
);


1;

