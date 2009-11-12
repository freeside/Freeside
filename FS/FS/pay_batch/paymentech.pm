package FS::pay_batch::paymentech;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Time::Local;
use Date::Format 'time2str';
use Date::Parse 'str2time';
use Tie::IxHash;
use FS::Conf;

my $conf;
my ($bin, $merchantID, $terminalID, $username);
$name = 'paymentech';

%import_info = (
  filetype    => 'XML',
  xmlrow         => [ qw(transResponse newOrderResp) ],
  fields      => [
    'paybatchnum',
    '_date',
    'approvalStatus',
    ],
  xmlkeys     => [
    'orderID',
    'respDateTime',
    'approvalStatus',
    ],
  'hook'        => sub {
      my ($hash, $oldhash) = @_;
      my ($mon, $day, $year, $hour, $min, $sec) = 
        $hash->{'_date'} =~ /^(..)(..)(....)(..)(..)(..)$/;
      $hash->{'_date'} = timelocal($sec, $min, $hour, $day, $mon-1, $year);
      $hash->{'paid'} = $oldhash->{'amount'};
    },
  'approved'    => sub { my $hash = shift;
                            $hash->{'approvalStatus'} 
    },
  'declined'    => sub { my $hash = shift;
                            ! $hash->{'approvalStatus'} 
    },
);

my %paytype = (
  'personal checking' => 'C',
  'personal savings'  => 'S',
  'business checking' => 'X',
  'business savings'  => 'X',
  );

%export_info = (
  init  => sub {
# Load this at run time
    eval "use XML::Writer";
    die $@ if $@;
    my $conf = shift;
    ($bin, $terminalID, $merchantID, $username) =
       $conf->config('batchconfig-paymentech');
    },
# Here we do all the work in the header function.
  header => sub {
    my $pay_batch = shift;
    my @cust_pay_batch = @{(shift)};
    my $count = 1;
    my $output;
    my $xml = new XML::Writer(OUTPUT => \$output, DATA_MODE => 1, DATA_INDENT => 2);
    $xml->startTag('transRequest', RequestCount => scalar(@cust_pay_batch) + 1);
    $xml->startTag('batchFileID');
    $xml->dataElement(userID => $username);
    $xml->dataElement(fileDateTime => time2str('%Y%m%d%H%M%S', time));
    $xml->dataElement(fileID => 'FILEID');
    $xml->endTag('batchFileID');

    foreach (@cust_pay_batch) {
      $xml->startTag('newOrder', BatchRequestNo => $count++);
      tie my %order, 'Tie::IxHash', (
        industryType => 'EC',
        transType    => 'AC',
        bin          => $bin,
        merchantID   => $merchantID,
        terminalID   => $terminalID,
        ($_->payby eq 'CARD') ? (
          ccAccountNum => $_->payinfo,
          ccExp        => time2str('%m%y', str2time($_->exp))
        ) : (
          ecpCheckRT      => ($_->payinfo =~ /@(\d+)/),
          ecpCheckDDA     => ($_->payinfo =~ /(\d+)@/),
          ecpBankAcctType => $paytype{lc($_->cust_main->paytype)},
          ecpDelvMethod   => 'A',
        ),
        avsZip          => $_->zip,
        avsAddress1     => $_->address1,
        avsAddress2     => $_->address2,
        avsCity         => $_->city,
        avsState        => $_->state,
        avsName        => $_->first . ' ' . $_->last,
        avsCountryCode => $_->country,
        orderID        => $_->paybatchnum,
        amount         => $_->amount * 100,
        );
      foreach my $key (keys %order) {
        $xml->dataElement($key, $order{$key})
      }
      $xml->endTag('newOrder');
    }
    $xml->startTag('endOfDay', BatchRequestNo => $count);
    $xml->dataElement(bin => $bin);
    $xml->dataElement(merchantID => $merchantID);
    $xml->dataElement(terminalID => $terminalID);
    $xml->endTag('endOfDay');
    $xml->endTag('transRequest');
    return $output;
  },
  row => sub {},
);

1;

