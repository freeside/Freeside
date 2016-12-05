#!/usr/bin/perl

use strict;
use FS::Test;
use Test::More;
use FS::Conf;
use FS::cust_main;
use Business::CreditCard qw(generate_last_digit);
use DateTime;
if ( stat('/usr/local/etc/freeside/cardfortresstest.txt') ) {
  plan tests => 20;
} else {
  plan skip_all => 'CardFortress test encryption key is not installed.';
}

### can only run on test database (company name "Freeside Test")
### will run upgrade, which uses lots of prints & warns beyond regular test output

my $fs = FS::Test->new( user => 'admin' );
my $conf = FS::Conf->new;
my $err;
my $bopconf;

like( $conf->config('company_name'), qr/^Freeside Test/, 'using test database' ) or BAIL_OUT('');

# some pre-upgrade cleanup, upgrade will fail if these are still configured
foreach my $cust_main ( $fs->qsearch('cust_main') ) {
  my @count = $fs->qsearch('agent_payment_gateway', { agentnum => $cust_main->agentnum } );
  if (@count > 1) {
    note("DELETING CARDTYPE GATEWAYS");
    foreach my $apg (@count) {
      $err = $apg->delete if $apg->cardtype;
      last if $err;
    }
    @count = $fs->qsearch('agent_payment_gateway', { agentnum => $cust_main->agentnum } );
    if (@count > 1) {
      $err = "Still found ".@count." gateways for custnum ".$cust_main->custnum;
      last;
    }
  }
}
ok( !$err, "remove obsolete payment gateways" ) or BAIL_OUT($err);

$bopconf = 
'IPPay
TESTTERMINAL';
$conf->set('business-onlinepayment' => $bopconf);
is( join("\n",$conf->config('business-onlinepayment')), $bopconf, "setting first default gateway" ) or BAIL_OUT('');

# generate a few void/refund records for upgrading
my $counter = 20;
foreach my $cust_pay ( $fs->qsearch('cust_pay',{ payby => 'CARD' }) ) {
  if ($counter % 2) {
    $err = $cust_pay->void('Testing');
    $err = "Voiding: $err" if $err;
  } else {
    # from realtime_refund_bop, just the important bits    
    while ( $cust_pay->unapplied < $cust_pay->paid ) {
      my @cust_bill_pay = $cust_pay->cust_bill_pay;
      last unless @cust_bill_pay;
      my $cust_bill_pay = pop @cust_bill_pay;
      $err = $cust_bill_pay->delete;
      $err = "Refund unapply: $err" if $err;
      last if $err;
    }
    last if $err;
    my $cust_refund = new FS::cust_refund ( {
      'custnum'  => $cust_pay->cust_main->custnum,
      'paynum'   => $cust_pay->paynum,
      'source_paynum' => $cust_pay->paynum,
      'refund'   => $cust_pay->paid,
      '_date'    => '',
      'payby'    => $cust_pay->payby,
      'payinfo'  => $cust_pay->payinfo,
      'reason'     => 'Testing',
      'gatewaynum'    => $cust_pay->gatewaynum,
      'processor'     => $cust_pay->payment_gateway ? $cust_pay->payment_gateway->processor : '',
      'auth'          => $cust_pay->auth,
      'order_number'  => $cust_pay->order_number,
    } );
    $err = $cust_refund->insert( reason_type => 'Refund' );
    $err = "Refunding: $err" if $err;
  }
  last if $err;
  $counter -= 1;
  last unless $counter > 0;
}
ok( !$err, "create some refunds and voids" ) or BAIL_OUT($err);

# also, just to test behavior in this case, create a record for an aborted
# verification payment. this will have no customer number.

my $pending_failed = FS::cust_pay_pending->new({
  'custnum_pending' => 1,
  'paid'    => '1.00',
  '_date'   => time - 86400,
  random_card(),
  'status'  => 'failed',
  'statustext' => 'Tokenization upgrade test',
});
$err = $pending_failed->insert;
ok( !$err, "create a failed payment attempt" ) or BAIL_OUT($err);

# find two stored credit cards.
my @cust = map { FS::cust_main->by_key($_) } (10, 12);
my @payby = map { ($_->cust_payby)[0] } @cust;
my @payment;

ok( $payby[0]->payby eq 'CARD' && !$payby[0]->tokenized,
  "first customer has a non-tokenized card"
  ) or BAIL_OUT();

$err = $cust[0]->realtime_cust_payby(amount => '2.00');
ok( !$err, "create a payment through IPPay" )
  or BAIL_OUT($err);
$payment[0] = $fs->qsearchs('cust_pay', { custnum => $cust[0]->custnum,
                                     paid => '2.00' })
  or BAIL_OUT("can't find payment record");

$err = system('freeside-upgrade','admin');
ok( !$err, 'initial upgrade' ) or BAIL_OUT('Error string: '.$!);

# switch to CardFortress
$bopconf =
'CardFortress
cardfortresstest
(TEST54)
Normal Authorization
gateway
IPPay
gateway_login
TESTTERMINAL
gateway_password

private_key
/usr/local/etc/freeside/cardfortresstest.txt';
$conf->set('business-onlinepayment' => $bopconf);
is( join("\n",$conf->config('business-onlinepayment')), $bopconf, "setting tokenizable default gateway" ) or BAIL_OUT('');

foreach my $pg ($fs->qsearch('payment_gateway')) {
  unless ($pg->gateway_module eq 'CardFortress') {
    note('UPGRADING NON-CF PAYMENT GATEWAY');
    my %pgopts = (
      gateway          => $pg->gateway_module,
      gateway_login    => $pg->gateway_username,
      gateway_password => $pg->gateway_password,
      private_key      => '/usr/local/etc/freeside/cardfortresstest.txt',
    );
    $pg->gateway_module('CardFortress');
    $pg->gateway_username('cardfortresstest');
    $pg->gateway_password('(TEST54)');
    $err = $pg->replace(\%pgopts);
    last if $err;
  }
}
ok( !$err, "remove non-CF payment gateways" ) or BAIL_OUT($err);

# create a payment using a non-tokenized card. this should immediately
# trigger tokenization.
ok( $payby[1]->payby eq 'CARD' && ! $payby[1]->tokenized,
  "second customer has a non-tokenized card"
  ) or BAIL_OUT();

$err = $cust[1]->realtime_cust_payby(amount => '3.00');
ok( !$err, "tokenize a card when it's first used for payment" )
  or BAIL_OUT($err);
$payment[1] = $fs->qsearchs('cust_pay', { custnum => $cust[1]->custnum,
                                     paid => '3.00' })
  or BAIL_OUT("can't find payment record");
ok( $payment[1]->tokenized, "payment is tokenized" );
$payby[1] = $payby[1]->replace_old;
ok( $payby[1]->tokenized, "card is now tokenized" );

# invoke the part of freeside-upgrade that tokenizes
FS::cust_main->queueable_upgrade();
#$err = system('freeside-upgrade','admin');
#ok( !$err, 'tokenizable upgrade' ) or BAIL_OUT('Error string: '.$!);

$payby[0] = $payby[0]->replace_old;
ok( $payby[0]->tokenized, "old card was tokenized during upgrade" );
$payment[0] = $payment[0]->replace_old;
ok( $payment[0]->tokenized, "old payment was tokenized during upgrade" );
ok( ($payment[0]->cust_pay_pending)[0]->tokenized, "old cust_pay_pending was tokenized during upgrade" );

$pending_failed = $pending_failed->replace_old;
ok( $pending_failed->tokenized, "cust_pay_pending with no customer was tokenized" );

# add a new payment card to one customer
$payby[2] = FS::cust_payby->new({
  custnum => $cust[0]->custnum,
  random_card(),
});
$err = $payby[2]->insert;
ok( !$err, "new card was saved" );
ok($payby[2]->tokenized, "new card is tokenized" );

sub random_card {
  my $payinfo = '4111' . join('', map { int(rand(10)) } 1 .. 11);
  $payinfo .= generate_last_digit($payinfo);
  my $paydate = DateTime->now
                ->add('years' => 1)
                ->truncate(to => 'month')
                ->strftime('%F');
  return ( 'payby'    => 'CARD',
           'payinfo'  => $payinfo,
           'paydate'  => $paydate,
           'payname'  => 'Tokenize Me',
  );
}


1;

