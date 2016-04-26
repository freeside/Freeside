#!/usr/bin/perl

use FS::Test;
use Test::More tests => 4;

my $FS = FS::Test->new;
# get the form
$FS->post('/edit/cust_main.cgi');
my $form = $FS->form('CustomerForm');

my %params = (
  residential_commercial  => 'Residential',
  agentnum                => 1,
  refnum                  => 1,
  last                    => 'Customer',
  first                   => 'New',
  invoice_email           => 'newcustomer@fake.freeside.biz',
  bill_address1           => '123 Example Street',
  bill_address2           => 'Apt. Z',
  bill_city               => 'Sacramento',
  bill_state              => 'CA',
  bill_zip                => '94901',
  bill_country            => 'US',
  bill_coord_auto         => 'Y',
  daytime                 => '916-555-0100',
  night                   => '916-555-0200',
  ship_address1           => '125 Example Street',
  ship_address2           => '3rd Floor',
  ship_city               => 'Sacramento',
  ship_state              => 'CA',
  ship_zip                => '94901',
  ship_country            => 'US',
  ship_coord_auto         => 'Y',
  invoice_ship_address    => 'Y',
  postal_invoice          => 'Y',
  billday                 => '1',
  no_credit_limit         => 1,
  # payment method
  custpaybynum0_payby         => 'CARD',
  custpaybynum0_payinfo       => '4012888888881881',
  custpaybynum0_paydate_month => '12',
  custpaybynum0_paydate_year  => '2020',
  custpaybynum0_paycvv        => '123',
  custpaybynum0_payname       => '',
  custpaybynum0_weight        => 1,
);
foreach (keys %params) {
  $form->value($_, $params{$_});
}
$FS->post($form);
ok( $FS->error eq '' , 'form posted' );
if (
  ok($FS->redirect =~ m[^/view/cust_main.cgi\?(\d+)], 'new customer accepted')
) {
  my $custnum = $1;
  my $cust = $FS->qsearchs('cust_main', { custnum => $1 });
  isa_ok ( $cust, 'FS::cust_main' );
  $FS->post($FS->redirect);
  ok ( $FS->error eq '' , 'can view customer' );
} else {
  # try to display the error message, or if not, show everything
  $FS->post($FS->redirect);
  diag ($FS->error);
  done_testing(2);
}

1;
