package FS::pay_batch::paymentech;

use strict;
use vars qw(@ISA %import_info %export_info $name);
use Time::Local;
use Date::Format 'time2str';
use Date::Parse 'str2time';
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
    eval "use XML::Simple";
    die $@ if $@;
    my $conf = shift;
    ($bin, $terminalID, $merchantID, $username) =
       $conf->config('batchconfig-paymentech');
    },
# Here we do all the work in the header function.
  header => sub {
    my $pay_batch = shift;
    my @cust_pay_batch = @{(shift)};
    my $count = 0;
    XML::Simple::XMLout( {
      transRequest => {
        RequestCount => scalar(@cust_pay_batch),
        batchFileID  => {
          userID        => $username,
          fileDateTime  => time2str('%Y%m%d%H%M%s',time),
          fileID        => 'batch'.time2str('%Y%m%d',time),
        },
        newOrder => [ map { {
          # $_ here refers to a cust_pay_batch record.
          BatchRequestNo => $count++,
          industryType   => 'EC',
          transType      => 'AC',
          bin            => $bin,
          merchantID     => $merchantID,
          terminalID     => $terminalID,
          ($_->payby eq 'CARD') ? (
            # Credit card stuff
            ccAccountNum   => $_->payinfo,
            ccExp          => time2str('%y%m',str2time($_->exp)),
          ) : (
            # ECP (electronic check) stuff
            ecpCheckRT     => ($_->payinfo =~ /@(\d+)/),
            ecpCheckDDA    => ($_->payinfo =~ /(\d+)@/),
            ecpBankAcctType => $paytype{lc($_->cust_main->paytype)},
            ecpDelvMethod  => 'B'
          ),
          avsZip         => $_->zip,
          avsAddress1    => $_->address1,
          avsAddress2    => $_->address2,
          avsCity        => $_->city,
          avsState       => $_->state,
          avsName        => $_->first . ' ' . $_->last,
          avsCountryCode => $_->country,
          orderID        => $_->paybatchnum,
          amount         => $_->amount * 100,
          } } @cust_pay_batch
        ],
        endOfDay => {
          BatchRequestNo => $count++,
          bin            => $bin,
          merchantID     => $merchantID,
          terminalID     => $terminalID
        },
      } 
    }, KeepRoot => 1, NoAttr => 1);
  },
  row => sub {},
);

1;

