package FS::pay_batch::paymentech;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use FS::Record 'qsearchs';
use Time::Local;
use Date::Format 'time2str';
use Date::Parse 'str2time';
use Tie::IxHash;
use FS::Conf;
use FS::Misc 'bytes_substr';

my $conf;
my ($bin, $merchantID, $terminalID, $username, $password, $with_recurringInd);
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
    'auth',
    'procStatus',
    'procStatusMessage',
    'respCodeMessage',
    ],
  xmlkeys     => [
    'orderID',
    'respDateTime',
    'approvalStatus',
    'txRefNum',
    'authorizationCode',
    'procStatus',
    'procStatusMessage',
    'respCodeMessage',
    ],
  'hook'        => sub {
      if ( !$gateway ) {
        # find a gateway configuration that has the same merchantID 
        # as the batch config, if there is one.  If not, leave 
        # gateway out entirely.
        my $merchant = (FS::Conf->new->config('batchconfig-paymentech'))[2];
        $gateway = qsearchs({
              'table'     => 'payment_gateway',
              'addl_from' => ' JOIN payment_gateway_option USING (gatewaynum) ',
              'hashref'   => {  disabled    => '',
                                optionname  => 'merchant_id',
                                optionvalue => $merchant,
                              },
              });
      }
      my ($hash, $oldhash) = @_;
      $hash->{'gatewaynum'} = $gateway->gatewaynum if $gateway;
      $hash->{'processor'} = 'PaymenTech';
      my ($mon, $day, $year, $hour, $min, $sec) = 
        $hash->{'_date'} =~ /^(..)(..)(....)(..)(..)(..)$/;
      $hash->{'_date'} = timelocal($sec, $min, $hour, $day, $mon-1, $year);
      $hash->{'paid'} = $oldhash->{'amount'};
      if ( $hash->{'procStatus'} == 0 ) {
        $hash->{'error_message'} = $hash->{'respCodeMessage'};
      } else {
        $hash->{'error_message'} = $hash->{'procStatusMessage'};
      }
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

my %paymentech_countries = map { $_ => 1 } qw( US CA GB UK );

%export_info = (
  init  => sub {
# Load this at run time
    eval "use XML::Writer";
    die $@ if $@;
    my $conf = shift;
    ($bin, $terminalID, $merchantID, $username, $password, $with_recurringInd) =
       $conf->config('batchconfig-paymentech');
    },
# Here we do all the work in the header function.
  header => sub {
    my $pay_batch = shift;
    my @cust_pay_batch = @{(shift)};
    my $count = 1;
    my $output;
    my $xml = XML::Writer->new(
      OUTPUT => \$output,
      DATA_MODE => 1,
      DATA_INDENT => 2,
      ENCODING => 'utf-8'
    );
    $xml->xmlDecl(); # it is in the spec
    $xml->startTag('transRequest', RequestCount => scalar(@cust_pay_batch) + 1);
    $xml->startTag('batchFileID');
    $xml->dataElement(userID => $username);
    $xml->dataElement(fileDateTime => time2str('%Y%m%d%H%M%S', time));
    $xml->dataElement(fileID => 'FILEID');
    $xml->endTag('batchFileID');

    foreach (@cust_pay_batch) {
      $xml->startTag('newOrder', BatchRequestNo => $count++);
      my $status = $_->cust_main->status;
      tie my %order, 'Tie::IxHash', (
        industryType    => 'EC',
        transType       => 'AC',
        bin             => $bin,
        merchantID      => $merchantID,
        terminalID      => $terminalID,
        ($_->payby eq 'CARD') ? (
          ccAccountNum    => $_->payinfo,
          ccExp           => $_->expmmyy,
        ) : (
          ecpCheckRT      => ($_->payinfo =~ /@(\d+)/),
          ecpCheckDDA     => ($_->payinfo =~ /(\d+)@/),
          ecpBankAcctType => $paytype{lc($_->paytype)},
          ecpDelvMethod   => 'A',
        ),
        avsZip          => bytes_substr($_->zip,      0, 10),
        avsAddress1     => bytes_substr($_->address1, 0, 30),
        avsAddress2     => bytes_substr($_->address2, 0, 30),
        avsCity         => bytes_substr($_->city,     0, 20),
        avsState        => bytes_substr($_->state,    0, 2),
        avsName         => bytes_substr($_->first. ' '. $_->last, 0, 30),
        ( $paymentech_countries{ $_->country }
          ? ( avsCountryCode  => $_->country )
          : ()
        ),
        orderID           => $_->paybatchnum,
        amount            => $_->amount * 100,
        );
      # only do this if recurringInd is enabled in config, 
      # and the customer has at least one non-canceled recurring package
      if ( $with_recurringInd and $status =~ /^active|suspended|ordered$/ ) {
        # then send RF if this is the first payment on this payinfo,
        # RS otherwise.
        $order{'recurringInd'} = $_->payinfo_used ? 'RS' : 'RF';
      }
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

# Including this means that there is a Business::BatchPayment module for
# this gateway and we want to upgrade it.
# Must return the name of the module, followed by a hash of options.

sub _upgrade_gateway {
  my $conf = FS::Conf->new;
  my @batchconfig = $conf->config('batchconfig-paymentech');
  my %options;
  @options{ qw(
    bin
    terminalID
    merchantID
    login
    password
    with_recurringInd
  ) } = @batchconfig;
  $options{'industryType'} = 'EC';
  ( 'Paymentech', %options );
}

1;
