#!/usr/bin/perl

=head2 DESCRIPTION

Tests automatic lookup of Washington sales tax districts and rates.

This will set up two tax classes. One of them (class A) has only the sales
tax. The other (class B) will have an additional, manually created tax.

This will test the following sequence of actions (running
process_district_update() after each one):

1. Enter a customer in Washington for which there is not yet a district tax
   entry.
2. Add a manual tax in class B.
3. Rename the sales taxes.
4. Delete the sales taxes.
5. Change the sales tax rates (to simulate a change in the actual rate).
6. Set the sales tax rate to zero.

The correct result is always for there to be exactly one tax entry for this
district in each class, with the correct rate, except after step 6, when
the rate should remain at zero (because setting the rate to zero is a way
of manually disabling the tax).

=cut

use strict;
use Test::More tests => 6;
use FS::Test;
use FS::cust_main;
use FS::cust_location;
use FS::cust_main_county;
use FS::Misc;
use FS::Conf;
my $FS= FS::Test->new;

my $error;

# start clean
my @taxes = $FS->qsearch('cust_main_county', { city => 'SEATTLE' });
my @classes = $FS->qsearch('part_pkg_taxclass');
foreach (@taxes, @classes) {
  $error = $_->delete;
  BAIL_OUT("can't flush existing taxes: $error") if $error;
  # we won't charge any of the taxes in this script so FK errors shouldn't
  # happen.
}

# configure stuff
@classes = map { FS::part_pkg_taxclass->new({ taxclass => $_ }) }
  qw( ClassA ClassB );
foreach (@classes) {
  $error = $_->insert;
  BAIL_OUT("can't create tax class: $error") if $error;
}

# should be an FS::Test method to temporarily set this up
my $conf = FS::Conf->new;
$conf->set('tax_district_method', 'wa_sales');
$conf->set('tax_district_taxname', 'Sales Tax');
$conf->set('enable_taxclasses', 1);

# create the customer
my $cust = $FS->new_customer('WA Taxes');
# Sea-Tac International Airport
$cust->bill_location->address1('17801 International Blvd');
$cust->bill_location->city('Seattle');
$cust->bill_location->zip('98158');
$cust->bill_location->state('WA');
$cust->bill_location->country('US');

$error = $cust->insert;
BAIL_OUT("can't create test customer: $error") if $error;

my $location = $cust->bill_location;
my @prev_taxes;

# after each action, refresh the tax district (as if we'd added/edited a
# customer in that district) and then get the new list of defined taxes
sub reprocess {
  # remember all the taxes from the last test
  @prev_taxes = map { $_ && FS::cust_main_county->new({$_->hash}) } @taxes;
  local $@;
  eval { FS::geocode_Mixin::process_district_update( 'FS::cust_location',
         $location->locationnum )};
  $error = $@;
  BAIL_OUT("can't update tax district: $error") if $error;

  $location = $location->replace_old;
  @taxes = $FS->qsearch({
    table => 'cust_main_county',
    hashref => { city => 'SEATTLE' },
    order_by => 'ORDER BY taxclass ASC, taxname ASC', # make them easily findable
  });
}

# and then we'll want to check that the total number of taxes is what we
# expect.
sub ok_num_taxes {
  my $num = shift;
  is( scalar(@taxes), $num, "Number of taxes" )
    or BAIL_OUT('Wrong number of tax records, can\'t continue.');
}

subtest 'Step 1: Initial tax lookup' => sub {
  plan 'tests' => 4;
  reprocess();
  ok( $location->district, 'Found district '.$location->district);
  ok_num_taxes(2);
  ok( (   $taxes[0]
      and $taxes[0]->taxname eq 'Sales Tax'
      and $taxes[0]->taxclass eq 'ClassA'
      and $taxes[0]->district eq $location->district
      and $taxes[0]->source eq 'wa_sales'
      and $taxes[0]->tax > 0
      ),
    'ClassA tax = '.$taxes[0]->tax )
    or diag explain($taxes[0]);
  ok( (   $taxes[1] 
      and $taxes[1]->taxname eq 'Sales Tax'
      and $taxes[1]->taxclass eq 'ClassB'
      and $taxes[1]->district eq $location->district
      and $taxes[1]->source eq 'wa_sales'
      and $taxes[1]->tax > 0
      ),
    'ClassB tax = '.$taxes[1]->tax )
    or diag explain($taxes[1]);
};

# "Sales Tax" sorts before "USF"; this is intentional.
subtest 'Step 2: Add manual tax ("USF") to ClassB' => sub {
  plan tests => 4;
  if ($taxes[1]) {
    my $manual_tax = $taxes[1]->new({
      $taxes[1]->hash,
      'taxnum'  => '',
      'taxname' => 'USF',
      'source'  => '',
      'tax'     => '17',
    });
    $error = $manual_tax->insert;
    BAIL_OUT("can't create manual tax: $error") if $error;
  }
  reprocess();
  ok_num_taxes(3);
  is_deeply( $taxes[0], $prev_taxes[0], 'ClassA sales tax was not changed' );
  is_deeply( $taxes[1], $prev_taxes[1], 'ClassB sales tax was not changed' );
  ok( (   $taxes[2]
      and $taxes[2]->taxname eq 'USF'
      and $taxes[2]->taxclass eq 'ClassB'
      and $taxes[2]->tax == 17
      and $taxes[2]->source eq ''
    ), 'Manual tax was accepted')
    or diag explain($taxes[2]);
};

subtest 'Step 3: Rename ClassB sales tax. Does it stay renamed?' => sub {
  plan tests => 4;
  if ($taxes[1]) {
    $taxes[1]->set('taxname', 'Renamed Sales Tax');
    $error = $taxes[1]->replace;
    BAIL_OUT("can't rename tax: $error") if $error;
  }

  reprocess();
  ok_num_taxes(3);
  is_deeply( $taxes[0], $prev_taxes[0], 'ClassA sales tax was not changed' );
  ok( (   $taxes[1]
      and $taxes[1]->taxname eq 'Renamed Sales Tax'
      and $taxes[1]->source eq 'wa_sales'
      and $taxes[1]->tax == $prev_taxes[1]->tax
    ), $taxes[1]->taxclass .' sales tax was renamed')
    or diag explain($taxes[1]);
  is_deeply( $taxes[2], $prev_taxes[2], 'ClassB manual tax was not changed' );
};

subtest 'Step 4: Remove ClassB sales tax. Is it recreated?' => sub {
  plan tests => 4;
  if ($taxes[1]) {
    $error = $taxes[1]->delete;
    BAIL_OUT("can't delete tax: $error") if $error;
  }
  reprocess();
  ok_num_taxes(3);
  is_deeply( $taxes[0], $prev_taxes[0], 'ClassA sales tax was not changed' );
  ok( (   $taxes[1]
      and $taxes[1]->taxname eq 'Sales Tax'
      and $taxes[1]->source eq 'wa_sales'
      and $taxes[1]->tax == $prev_taxes[1]->tax
    ), $taxes[1]->taxclass .' sales tax was deleted and recreated')
    or diag explain($taxes[1]);
  is_deeply( $taxes[2], $prev_taxes[2], 'ClassB manual tax was not changed' );
};

subtest 'Step 5: Simulate a change in tax rate. Do the taxes update?' => sub {
  plan tests => 3;
  my $correct_rate = $taxes[0]->tax;
  foreach (@taxes[0,1]) {
    if ($_ and $_->source eq 'wa_sales') {
      $_->tax( $correct_rate + 1 );
      $error = $_->replace;
      BAIL_OUT("can't change tax rate: $error") if $error;
    }
  }
  reprocess();
  ok_num_taxes(3);
  ok( (   $taxes[0] and $taxes[0]->tax == $correct_rate
      and $taxes[1] and $taxes[1]->tax == $correct_rate
    ), 'Tax was reset to correct rate' )
    or diag("Tax rates: ".$taxes[0]->tax.', '.$taxes[1]->tax);
  is_deeply( $taxes[2], $prev_taxes[2], 'ClassB manual tax was not changed' );
};

subtest 'Step 6: Manually disable Class A sales tax. Does it stay disabled?' => sub {
  plan tests => 4;
  if ($taxes[0]) {
    $taxes[0]->set('tax', 0);
    $error = $taxes[0]->replace;
    BAIL_OUT("can't change tax rate to zero: $error") if $error;
  }
  reprocess();
  ok_num_taxes(3);
  ok( $taxes[0]->tax == 0, 'ClassA sales tax remains at zero')
    or diag("Tax rate: ".$taxes[1]->tax);
  is_deeply( $taxes[1], $prev_taxes[1], 'ClassB sales tax was not changed' );
  is_deeply( $taxes[2], $prev_taxes[2], 'ClassB manual tax was not changed' );
};

$conf->delete('tax_district_method');
$conf->delete('tax_district_taxname');
$conf->delete('enable_taxclasses');
