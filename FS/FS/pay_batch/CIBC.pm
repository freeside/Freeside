package FS::pay_batch::CIBC;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Date::Format 'time2str';
use FS::Conf;

my $conf;
my ($origid, $datacenter, $transcode, $shortname, $mybank, $myacct);

$name = 'CIBC';

%import_info = (
  'filetype'    => 'CSV',
  'fields'      => [],
  'hook'        => sub { die "Can't import CIBC" },
  'approved'    => sub { 1 },
  'declined'    => sub { 0 },
);

%export_info = (
  init => sub {
    $conf = shift;
    ($origid,
     $datacenter,
     $transcode, 
     $shortname, 
     $mybank, 
     $myacct) = $conf->config("batchconfig-CIBC");
  },
  header => sub { 
    my $pay_batch = shift;
    sprintf( "1%2s%05u%-5s%010u%6s%04u%1s%04u%5u%-12u%2s%-15s%1s%3s%4s \n",  #80
      '',
      substr(0,5, $origid),
      '',
      $origid,
      time2str('%y%m%d', $pay_batch->download),
      $pay_batch->batchnum,
      ' ',
      '0010',
      $mybank,
      $myacct,
      '',
      $shortname,
      ' ',
      'CAD',
      '', ) .
    sprintf( "5%46s%03u%-10s%6s%14s", #80
      '',
      $transcode,
      '           ',
      time2str('%y%m%d', $pay_batch->download),
      '               ');
  },
  row => sub {
    my ($cust_pay_batch, $pay_batch) = @_;
    my ($account, $aba) = split('@', $cust_pay_batch->payinfo);
    my($bankno, $branch);
    if ( $aba =~ /^0(\d{3})(\d{5})$/ ) { # standard format for Canadian bank ID
      ($bankno, $branch) = ( $1, $2 );
    } elsif ( $aba =~ /^(\d{5})\.(\d{3})$/ ) { #how we store branches
      ($branch, $bankno) = ( $1, $2 );
    } else {
      die "invalid branch/routing number '$aba'\n";
    }
    sprintf( "6%1s%1s%04u%05u%-12u%5u%10s%-13s%-22s%6s ", #80
      'D',
      '',
      $bankno,
      $branch,
      $account,
      '',
      $cust_pay_batch->amount * 100,
      $cust_pay_batch->paybatchnum,
      $cust_pay_batch->payname,
      '     ',
      );
  },
  footer => sub {
    my ($pay_batch, $batchcount, $batchtotal) = @_;
    sprintf( "7%03u%06f%010s%20s%012s%28s \n", $transcode, $batchcount,'0','',$batchtotal*100,''). #80
    sprintf( "9%06s%06s%67s", 1, $batchcount,''); #80
  },
);

1;
