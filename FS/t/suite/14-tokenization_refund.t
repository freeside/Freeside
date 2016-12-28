#!/usr/bin/perl

use strict;
use FS::Test;
use Test::More;
use FS::Conf;
use FS::cust_main;
use Business::CreditCard qw(generate_last_digit);
use DateTime;
if ( stat('/usr/local/etc/freeside/cardfortresstest.txt') ) {
  plan tests => 66;
} else {
  plan skip_all => 'CardFortress test encryption key is not installed.';
}

#local $FS::cust_main::Billing_Realtime::DEBUG = 2;

my $fs = FS::Test->new( user => 'admin' );
my $conf = FS::Conf->new;
my $err;
my @bopconf;

### can only run on test database (company name "Freeside Test")
like( $conf->config('company_name'), qr/^Freeside Test/, 'using test database' ) or BAIL_OUT('');

# these will just get in the way for now
foreach my $apg ($fs->qsearch('agent_payment_gateway')) {
  $err = $apg->delete;
  last if $err;
}
ok( !$err, 'removing agent gateway overrides' ) or BAIL_OUT($err);

# will need this
my $reason = FS::reason->new_or_existing(
  reason => 'Token Test',
  type   => 'Refund',
  class  => 'F',
);
isa_ok ( $reason, 'FS::reason', "refund reason" ) or BAIL_OUT('');

# non-tokenizing gateway
push @bopconf,
'IPPay
TESTTERMINAL';

# tokenizing gateway
push @bopconf,
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

foreach my $voiding (0,1) {
  my $noun = $voiding ? 'void' : 'refund';

  if ($voiding) {
    $conf->delete('disable_void_after');
    ok( !$conf->exists('disable_void_after'), 'set disable_void_after to produce voids' ) or BAIL_OUT('');
  } else {
    $conf->set('disable_void_after' => '0');
    is( $conf->config('disable_void_after'), '0', 'set disable_void_after to produce refunds' ) or BAIL_OUT('');
  }

  # for attempting refund post-tokenization
  my $n_cust_main;
  my $n_cust_pay;

  foreach my $tokenizing (0,1) {
    my $adj = $tokenizing ? 'tokenizable' : 'non-tokenizable';

    # set payment gateway
    $conf->set('business-onlinepayment' => $bopconf[$tokenizing]);
    is( join("\n",$conf->config('business-onlinepayment')), $bopconf[$tokenizing], "set $adj $noun default gateway" ) or BAIL_OUT('');

    # make sure we're upgraded, only need to do it once,
    # use non-tokenizing gateway for speed,
    # but doesn't matter if existing records are tokenized or not,
    # this suite is all about testing new record creation
    if (!$tokenizing && !$voiding) {
      $err = system('freeside-upgrade','-q','admin');
      ok( !$err, 'upgrade freeside' ) or BAIL_OUT('Error string: '.$!);
    }

    if ($tokenizing) {

      my $n_paynum = $n_cust_pay->paynum;

      # refund the previous non-tokenized payment through CF
      $err = $n_cust_main->realtime_refund_bop({
        reasonnum => $reason->reasonnum,
        paynum    => $n_paynum,
        method    => 'CC',
      });
      ok( !$err, "run post-switch $noun" ) or BAIL_OUT($err);

      my $n_cust_pay_void = $fs->qsearchs('cust_pay_void',{ paynum => $n_paynum });
      my $n_cust_refund   = $fs->qsearchs('cust_refund',{ source_paynum => $n_paynum });

      if ($voiding) {

        # check for void record
        isa_ok( $n_cust_pay_void, 'FS::cust_pay_void', 'post-switch void') or BAIL_OUT("paynum $n_paynum");

        # check that void tokenized
        ok ( $n_cust_pay_void->tokenized, "post-switch void tokenized" ) or BAIL_OUT("paynum $n_paynum");

        # check for no refund record
        ok( !$n_cust_refund, "post-switch void did not generate cust_refund" ) or BAIL_OUT("paynum $n_paynum");

      } else {

        # check for refund record
        isa_ok( $n_cust_refund, 'FS::cust_refund', 'post-switch refund') or BAIL_OUT("paynum $n_paynum");

        # check that refund tokenized
        ok ( $n_cust_refund->tokenized, "post-switch refund tokenized" ) or BAIL_OUT("paynum $n_paynum");

        # check for no refund record
        ok( !$n_cust_pay_void, "post-switch refund did not generate cust_pay_void" ) or BAIL_OUT("paynum $n_paynum");

      }

    }

    # create customer
    my $cust_main = $fs->new_customer($adj.'X'.$noun);
    isa_ok ( $cust_main, 'FS::cust_main', "$adj $noun customer" ) or BAIL_OUT('');

    # insert customer
    $err = $cust_main->insert;
    ok( !$err, "insert $adj $noun customer" ) or BAIL_OUT($err);

    # add card
    my $cust_payby;
    my %card = random_card();
    $err = $cust_main->save_cust_payby(
      %card,
      payment_payby => $card{'payby'},
      auto => 1,
      saved_cust_payby => \$cust_payby
    );
    ok( !$err, "save $adj $noun card" ) or BAIL_OUT($err);

    # retrieve card
    isa_ok ( $cust_payby, 'FS::cust_payby', "$adj $noun card" ) or BAIL_OUT('');

    # check that card tokenized or not
    if ($tokenizing) {
      ok( $cust_payby->tokenized, "new $noun cust card tokenized" ) or BAIL_OUT('');
    } else {
      ok( !$cust_payby->tokenized, "new $noun cust card not tokenized" ) or BAIL_OUT('');
    }

    # run a payment
    $err = $cust_main->realtime_cust_payby( amount => '1.00' );
    ok( !$err, "run $adj $noun payment" ) or BAIL_OUT($err);

    # get the payment
    my $cust_pay = $fs->qsearchs('cust_pay',{ custnum => $cust_main->custnum }); 
    isa_ok ( $cust_pay, 'FS::cust_pay', "$adj $noun payment" ) or BAIL_OUT('');

    # refund the payment
    $err = $cust_main->realtime_refund_bop({
      reasonnum => $reason->reasonnum,
      paynum    => $cust_pay->paynum,
      method    => 'CC',
    });
    ok( !$err, "run $adj $noun" ) or BAIL_OUT($err);

    unless ($tokenizing) {

      # run a second payment, to refund after switch
      $err = $cust_main->realtime_cust_payby( amount => '2.00' );
      ok( !$err, "run $adj $noun second payment" ) or BAIL_OUT($err);
    
      # get the second payment
      $n_cust_pay = $fs->qsearchs('cust_pay',{ custnum => $cust_main->custnum, paid => '2.00' });
      isa_ok ( $n_cust_pay, 'FS::cust_pay', "$adj $noun second payment" ) or BAIL_OUT('');

      $n_cust_main = $cust_main;

    }

    #check that all transactions tokenized or not
    foreach my $table (qw(cust_pay_pending cust_pay cust_pay_void cust_refund)) {
      foreach my $record ($fs->qsearch($table,{ custnum => $cust_main->custnum })) {
        if ($tokenizing) {
          $err = "record not tokenized: $table ".$record->get($record->primary_key)
            unless $record->tokenized;
        } else {
          $err = "record tokenized: $table ".$record->get($record->primary_key)
            if $record->tokenized;
        }
        last if $err;
      }
    }
    ok( !$err, "$adj transaction token check" ) or BAIL_OUT($err);

    if ($voiding) {

      #make sure we voided
      ok( $fs->qsearch('cust_pay_void',{ custnum => $cust_main->custnum}), "$adj $noun record found" ) or BAIL_OUT('');

      #make sure we didn't generate refund records
      ok( !$fs->qsearch('cust_refund',{ custnum => $cust_main->custnum}), "$adj $noun did not generate cust_refund" ) or BAIL_OUT('');

    } else {

      #make sure we refunded
      ok( $fs->qsearch('cust_refund',{ custnum => $cust_main->custnum}), "$adj $noun record found" ) or BAIL_OUT('');

      #make sure we didn't generate void records
      ok( !$fs->qsearch('cust_pay_void',{ custnum => $cust_main->custnum}), "$adj $noun did not generate cust_pay_void" ) or BAIL_OUT('');

    }

  } #end of tokenizing or not

} # end of voiding or not

exit;

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

