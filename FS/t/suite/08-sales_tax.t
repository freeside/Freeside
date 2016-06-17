#!/usr/bin/perl

=head2 DESCRIPTION

Tests basic sales tax calculations, including consolidation and rounding.
The invoice will have two charges that add up to $50 and two taxes:
- Tax 1, 8.25%, for $4.125 in tax, which will round up.
- Tax 2, 8.245%, for $4.1225 in tax, which will round down.

Correct: The invoice will have one line item for each of those taxes, with
the correct amount.

=cut

use strict;
use Test::More tests => 2;
use FS::Test;
use Date::Parse 'str2time';
use Date::Format 'time2str';
use Test::MockTime qw(set_fixed_time);
use FS::cust_main;
use FS::cust_pkg;
use FS::Conf;
my $FS= FS::Test->new;

# test configuration
my @taxes = (
  [ 'Tax 1', 8.250, 4.13 ],
  [ 'Tax 2', 8.245, 4.12 ],
);
 
# Create the customer and charge them
my $cust = $FS->new_customer('Basic taxes');
$cust->bill_location->state('AZ'); # move it away from the default of CA
my $error;
$error = $cust->insert;
BAIL_OUT("can't create test customer: $error") if $error;
$error = $cust->charge( {
  amount    => 25.00,
  pkg       => 'Test charge 1',
} ) || 
$cust->charge({
  amount    => 25.00,
  pkg       => 'Test charge 2',
});
BAIL_OUT("can't create test charges: $error") if $error;

# Create tax defs
foreach my $tax (@taxes) {
  my $cust_main_county = FS::cust_main_county->new({
    'country'       => 'US',
    'state'         => 'AZ',
    'exempt_amount' => 0.00,
    'taxname'       => $tax->[0],
    'tax'           => $tax->[1],
  });
  $error = $cust_main_county->insert;
  BAIL_OUT("can't create tax definitions: $error") if $error;
}

# Bill the customer
set_fixed_time(str2time('2016-03-10 08:00'));
my @return;
$error = $cust->bill( return_bill => \@return );
BAIL_OUT("can't bill charges: $error") if $error;
my $cust_bill = $return[0] or BAIL_OUT("no invoice generated");
# Check amounts
diag("Tax on 25.00 + 25.00");
foreach my $cust_bill_pkg ($cust_bill->cust_bill_pkg) {
  next if $cust_bill_pkg->pkgnum;
  my ($tax) = grep { $_->[0] eq $cust_bill_pkg->itemdesc } @taxes;
  if ( $tax ) {
    ok ( $cust_bill_pkg->setup eq $tax->[2], "Tax at rate $tax->[1]% = $tax->[2]")
      or diag("is ". $cust_bill_pkg->setup);
  }
}
