package FS::pay_batch::paymentech;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use FS::Record 'qsearchs';
use Time::Local;
use Date::Format 'time2str';
use Date::Parse 'str2time';
use Tie::IxHash;
use FS::Conf;

my $conf;
my ($bin, $merchantID, $terminalID, $username);
$name = 'paymentech';

my $gateway;

%import_info = (
  filetype    => 'XML',
  xmlrow         => [ qw(transResponse newOrderResp) ],
  fields      => [
    'paybatchnum',
    '_date',
    'approvalStatus',
    'order_number',
    'authorization',
    ],
  xmlkeys     => [
    'orderID',
    'respDateTime',
    'approvalStatus',
    'txRefNum',
    'authorizationCode',
    ],
  'hook'        => sub {
      if ( !$gateway ) {
        # find a gateway configuration that has the same merchantID 
        # as the batch config, if there is one.  If not, leave 
        # gateway out entirely.
        my $merchant = (FS::Conf->new->config('batchconfig-paymentech'))[2];
        my $g = qsearchs({
              'table'     => 'payment_gateway',
              'addl_from' => ' JOIN payment_gateway_option USING (gatewaynum) ',
              'hashref'   => {  disabled    => '',
                                optionname  => 'merchant_id',
                                optionvalue => $merchant,
                              },
              });
        $gateway = ($g ? $g->gatewaynum . '-' : '') . 'PaymenTech';
      }
      my ($hash, $oldhash) = @_;
      my ($mon, $day, $year, $hour, $min, $sec) = 
        $hash->{'_date'} =~ /^(..)(..)(....)(..)(..)(..)$/;
      $hash->{'_date'} = timelocal($sec, $min, $hour, $day, $mon-1, $year);
      $hash->{'paid'} = $oldhash->{'amount'};
      $hash->{'paybatch'} = join(':', 
        $gateway,
        $hash->{'authorization'},
        $hash->{'order_number'},
      );
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
        avsZip          => substr($_->zip, 0, 10),
        avsAddress1     => substr($_->address1, 0, 30),
        avsAddress2     => substr($_->address2, 0, 30),
        avsCity         => substr($_->city, 0, 20),
        avsState        => $_->state,
        avsName        => substr($_->first . ' ' . $_->last, 0, 30),
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

