package FS::pay_batch::RBC;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Date::Format 'time2str';
use FS::Conf;
use Encode 'encode';

my $conf;
my ($client_num, $shortname, $longname, $trans_code, $testmode, $i, $declined, $totaloffset);

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
#
# additional info available at https://www.rbcroyalbank.com/ach/cid-213166.html
%import_info = (
  'filetype'    => 'fixed',
  #this only really applies to Debit Detail, but we otherwise only need first char
  'formatre'    => 
  '^(.).{18}(.{4}).{3}(.).{11}(.{19}).{6}(.{30}).{17}(.{9})(.{18}).{6}(.{14}).{23}(.).{9}\r?$',
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
      my $status = $hash->{'status'};
      my $message = '';
      if ($status eq 'E') {
        $message = 'Reversed payment';
      } elsif ($status eq 'R') {
        $message = 'Rejected payment';
      } elsif ($status eq 'U') {
        $message = 'Returned payment';
      } elsif ($status eq 'T') {
        $message = 'Error';
      } else {
        return 0;
      }
      $hash->{'error_message'} = $message;
      $declined->{$hash->{'paybatchnum'}} = 1;
      return 1;
  },
  'begin_condition' => sub {
      my $hash = shift;
      # Debit Detail Record
      if ($hash->{recordtype} eq '1') {
        $declined = {};
        $totaloffset = 0;
        return 1;
      # Credit Detail Record, will immediately trigger end condition & error
      } elsif ($hash->{recordtype} eq '2') { 
        return 1;
      } else {
        return 0;
      }
  },
  'end_hook'    => sub {
      my( $hash, $total, $line ) = @_;
      return "Can't process Credit Detail Record, aborting import"
        if ($hash->{'recordtype'} eq '2');
      $totaloffset = sprintf("%.2f", $totaloffset / 100 );
      $total += $totaloffset;
      $total = sprintf("%.2f", $total);
      # We assume here that this is an 'All Records' or 'Input Records' report.
      my $batch_total = sprintf("%.2f", substr($line, 59, 18) / 100);
      return "Our total $total does not match bank total $batch_total!"
        if $total != $batch_total;
      return '';
  },
  'end_condition' => sub {
      my $hash = shift;
      return ($hash->{recordtype} eq '4')  # Client Trailer Record
          || ($hash->{recordtype} eq '2'); # Credit Detail Record, will throw error in end_hook
  },
  'skip_condition' => sub {
      my $hash = shift;
      #we already declined it this run, no takebacks
      if ($declined->{$hash->{'paybatchnum'}}) {
        #file counts this as part of total, but we skip
        $totaloffset += $hash->{'paid'}
          if $hash->{'status'} eq ' '; #false laziness with 'approved' above
        return 1;
      }
      return 
        ($hash->{'recordtype'} eq '3') || #Account Trailer Record, concludes returned items
        ($hash->{'subtype'} ne '0'); #error messages, etc, too late to apply to previous entry
  },
);

%export_info = (
  init => sub {
    $conf = shift;
    ($client_num,
     $shortname,
     $longname,
     $trans_code, 
     $testmode
     ) = $conf->config("batchconfig-RBC");
    $testmode = '' unless $testmode eq 'TEST';
    $i = 1;
  },
  header => sub { 
    my $pay_batch = shift;
    my $mode = $testmode ? 'TEST' : 'PROD';
    my $filenum = $testmode ? 'TEST' : sprintf("%04u", $pay_batch->batchnum);
    '$$AAPASTD0152['.$mode.'[NL$$'."\n".
    '000001'.
    'A'.
    'HDR'.
    sprintf("%10s", $client_num).
    sprintf("%-30s", $longname).
    $filenum.
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
    time2str("%Y%j", time + 86400).
    sprintf("%-30.30s", encode('utf8', $cust_pay_batch->cust_main->first . ' ' .
                     $cust_pay_batch->cust_main->last)).
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

