#!/usr/bin/perl

=head2 DESCRIPTION

Tests crediting a package for unused time when it has sales tax. See
RT#42729.

The package will be billed for $30.00 with 10% tax, then credited for 1/3
of the billing period.

Correct: The credit amount will be $11.00.

=cut

use strict;
use Test::More tests => 3;
use FS::Test;
use Date::Parse 'str2time';
use Date::Format 'time2str';
use Test::MockTime qw(set_fixed_time);
use FS::cust_main;
use FS::cust_pkg;
use FS::part_pkg;
use FS::Conf;
my $FS= FS::Test->new;

# Create a package def
my $error;
my $part_pkg = FS::part_pkg->new({
  pkg     => 'Tax credit test',
  plan    => 'flat',
  freq    => '1',
  agentnum => 1,
});
my %options = (
  'setup_fee' => 0,
  'recur_fee' => 30.00,
  'recur_temporality' => 'upcoming',
  'unused_credit_cancel' => '1',
);
$error = $part_pkg->insert(options => \%options);
BAIL_OUT("can't create package def: $error") if $error;

# Create the customer and order a package
my $cust = $FS->new_customer('Credit unused with taxes');
$cust->bill_location->state('AK');
$error = $cust->insert;
BAIL_OUT("can't create test customer: $error") if $error;

my $pkg = FS::cust_pkg->new({ pkgpart => $part_pkg->pkgpart });
$error = $cust->order_pkg({ cust_pkg => $pkg });
BAIL_OUT("can't create test charges: $error") if $error;

# Create tax def
my $cust_main_county = FS::cust_main_county->new({
  'country'       => 'US',
  'state'         => 'AK',
  'exempt_amount' => 0.00,
  'taxname'       => 'Test tax',
  'tax'           => '10',
});
$error = $cust_main_county->insert;
BAIL_OUT("can't create tax definitions: $error") if $error;

# Bill the customer on Apr 1
# (April because it's 30 days, and also doesn't have DST)
set_fixed_time(str2time('2016-04-01 00:00'));
my @return;
$error = $cust->bill( return_bill => \@return );
BAIL_OUT("can't bill charges: $error") if $error;
my $cust_bill = $return[0] or BAIL_OUT("no invoice generated");

# Check amount
my ($tax_item) = grep { $_->itemdesc eq $cust_main_county->taxname }
                $cust_bill->cust_bill_pkg;
ok ( $tax_item && $tax_item->setup == 3.00, "Tax charged = 3.00" );

# sync
$pkg = $pkg->replace_old;

# Pay the bill in two parts
set_fixed_time(str2time('2016-04-02 00:00'));
foreach my $paid (10.00, 23.00) {
  my $cust_pay = FS::cust_pay->new({
    custnum => $cust->custnum,
    invnum  => $cust_bill->invnum,
    _date   => time,
    paid    => $paid,
    payby   => 'CASH',
  });
  $error = $cust_pay->insert;
  BAIL_OUT("can't record payment: $error") if $error;
}
# Now cancel with 1/3 of the period left
set_fixed_time(str2time('2016-04-21 00:00'));
$error = $pkg->cancel();
BAIL_OUT("can't cancel package: $error") if $error;

# and find the credit
my ($credit) = $cust->cust_credit
  or BAIL_OUT("no credit was created");
ok ( $credit->amount == 11.00, "Credited 1/3 of package charge with tax" )
  or diag("is ". $credit->amount );

# the invoice should also be fully paid after that
ok ( $cust_bill->owed == 0, "Invoice balance is zero" )
  or diag("is ". $cust_bill->owed);

