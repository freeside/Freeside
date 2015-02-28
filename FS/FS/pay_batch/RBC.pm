package FS::pay_batch::RBC;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Date::Format 'time2str';
use FS::Conf;

my $conf;
my ($client_num, $shortname, $longname, $trans_code, $i);

$name = 'RBC';
# Royal Bank of Canada ACH Direct Payments Service

# Meaning of initial characters in records:
# 0 - header row, skipped by begin_condition
# 1 - Debit Detail Record (only when subtype is 0)
# 2 - Credit Detail Record, we die with a parse error (shouldn't appear in freeside-generated batches)
# 3 - Account Trailer Record (appears after Returned items, we skip)
# 4 - Client Trailer Record, indicates end of batch in end_condition
#
# Subtypes (27th char) indicate different kinds of Debit/Credit records
# 0 - Credit/Debit Detail Record
# 3 - Error Message Record
# 4 - Foreign Currency Information Records
# We skip all subtypes except 0
%import_info = (
  'filetype'    => 'fixed',
  'formatre'    => 
  '^([0134]).{18}(.{4}).{3}(.).{11}(.{19}).{6}(.{30}).{17}(.{9})(.{18}).{6}(.{14}).{23}(.).{9}\r?$',
  'fields' => [ qw(
    recordtype
    batchnum
    subtype
    paybatchnum
    custname
    bank
    payinfo
    paid
    status
    ) ],
  'hook' => sub {
      my $hash = shift;
      $hash->{'paid'} = sprintf("%.2f", $hash->{'paid'} / 100 );
      $hash->{'_date'} = time;
      $hash->{'payinfo'} =~ s/^(\S+).*/$1/; # these often have trailing spaces
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
  'begin_condition' => sub {
      my $hash = shift;
      $hash->{recordtype} eq '1'; # Detail Record
  },
  'end_hook'    => sub {
      my( $hash, $total, $line ) = @_;
      $total = sprintf("%.2f", $total);
      # We assume here that this is an 'All Records' or 'Input Records'
      # report.
      my $batch_total = sprintf("%.2f", substr($line, 59, 18) / 100);
      return "Our total $total does not match bank total $batch_total!"
        if $total != $batch_total;
      '';
  },
  'end_condition' => sub {
      my $hash = shift;
      $hash->{recordtype} eq '4'; # Client Trailer Record
  },
  'skip_condition' => sub {
      my $hash = shift;
      $hash->{'recordtype'} eq '3' ||
        $hash->{'subtype'} ne '0';
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
    '$$AAPASTD0152[PROD[NL$$'."\n".
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
    my($bankno, $branch);
    if ( $aba =~ /^0(\d{3})(\d{5})$/ ) { # standard format for Canadian bank ID
      ($bankno, $branch) = ( $1, $2 );
    } elsif ( $aba =~ /^(\d{5})\.(\d{3})$/ ) { #how we store branches
      ($branch, $bankno) = ( $1, $2 );
    } else {
      die "invalid branch/routing number '$aba'\n";
    }

    $i++;
    sprintf("%06u", $i).
    'D'.
    sprintf("%3s",$trans_code).
    sprintf("%10s",$client_num).
    ' '.
    sprintf("%-19s", $cust_pay_batch->paybatchnum).
    '00'.
    sprintf("%04s", $bankno).
    sprintf("%05s", $branch).
    sprintf("%-18s", $account).
    ' '.
    sprintf("%010.0f",$cust_pay_batch->amount*100).
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
    '0' x 20 .
    sprintf("%06u", $batchcount).
    sprintf("%014.0f", $batchtotal*100).
    '00' .
    '000000' . # total number of customer information records
    ' ' x 84
    ;
  },
);

1;

