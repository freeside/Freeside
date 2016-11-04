#!/usr/bin/perl

use FS::Test;
use Test::More tests => 2;
use FS::cust_main;

my $FS = FS::Test->new;

# In the stock database, cust#5 has open invoices
my $cust_main = FS::cust_main->by_key(5);
my $balance = $cust_main->balance;
ok( $balance > 10.00, 'customer has an outstanding balance of more than $10.00' );

# Get the payment form
$FS->post('/misc/payment.cgi?payby=CARD;custnum=5');
my $form = $FS->form('OneTrueForm');
$form->value('amount'       => '10.00');
$form->value('custpaybynum' => '');
$form->value('payinfo'      => '4012888888881881');
$form->value('month'        => '01');
$form->value('year'         => '2020');
# payname and location fields should already be set
$form->value('save'         => 1);
$form->value('auto'         => 1);
$FS->post($form);

# on success, gives a redirect to the payment receipt
my $paynum;
if ($FS->redirect =~ m[^/view/cust_pay.html\?paynum=(\d+)]) {
  pass('payment processed');
  $paynum = $1;
} elsif ( $FS->error ) {
  fail('payment rejected');
  diag ( $FS->error );
} else {
  fail('unknown result');
  diag ( $FS->page );
}

1;
