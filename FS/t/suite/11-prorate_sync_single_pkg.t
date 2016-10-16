#!/usr/bin/perl

=head2 DESCRIPTION

Tests the effect of ordering a sync_bill_date package either before or
after noon and billing it for two consecutive cycles, in all three prorate
rounding modes (round nearest, round up, and round down). Ref RT#34622.

Correct: It should be charged full price in both cycles regardless of
the prorate rounding mode, as long as prorate rounding is enabled.

=cut

use strict;
use Test::More tests => 18;
use FS::Test;
use Date::Parse 'str2time';
use Date::Format 'time2str';
use Test::MockTime qw(set_fixed_time);
use FS::cust_main;
use FS::cust_pkg;
use FS::Conf;
my $FS= FS::Test->new;

foreach my $prorate_mode (1, 2, 3) {
  diag("prorate_round_day = $prorate_mode");
  # Create a package def with the sync_bill_date option.
  my $error;
  my $old_part_pkg = $FS->qsearchs('part_pkg', { pkgpart => 5 });
  my $part_pkg = $old_part_pkg->clone;
  BAIL_OUT("existing pkgpart 5 is not a flat monthly package")
    unless $part_pkg->freq eq '1' and $part_pkg->plan eq 'flat';
  $error = $part_pkg->insert(
    options => {  $old_part_pkg->options,
                  'sync_bill_date' => 1,
                  'prorate_round_day' => $prorate_mode, }
  );

  BAIL_OUT("can't configure package: $error") if $error;

  my $pkgpart = $part_pkg->pkgpart;
  # Create a clean customer with no other packages.
  foreach my $hour (0, 8, 16) {
    diag("$hour:00");
    my $location = FS::cust_location->new({
        address1  => '123 Example Street',
        city      => 'Sacramento',
        state     => 'CA',
        country   => 'US',
        zip       => '94901',
    });
    my $cust = FS::cust_main->new({
        agentnum      => 1,
        refnum        => 1,
        last          => 'Customer',
        first         => 'Sync bill date',
        invoice_email => 'newcustomer@fake.freeside.biz',
        payby         => 'BILL',
        bill_location => $location,
        ship_location => $location,
    });
    $error = $cust->insert;
    BAIL_OUT("can't create test customer: $error") if $error;

    my $pkg;
    # Create and bill the package.
    set_fixed_time(str2time("2016-03-10 $hour:00"));
    $pkg = FS::cust_pkg->new({ pkgpart => $pkgpart });
    $error = $cust->order_pkg({ 'cust_pkg' => $pkg });
    BAIL_OUT("can't order package: $error") if $error;
    $error = $cust->bill_and_collect;
    BAIL_OUT("can't bill package: $error") if $error;

    # Bill it a second time.
    $pkg = $pkg->replace_old;
    set_fixed_time($pkg->bill);
    $error = $cust->bill_and_collect;
    BAIL_OUT("can't bill package: $error") if $error;

    # Check the amount billed.
    my $recur = $part_pkg->base_recur;
    my @cust_bill = $cust->cust_bill;
    ok( $cust_bill[0]->charged == $recur, "first bill is $recur" )
      or diag("first bill is ".$cust_bill[0]->charged);
    ok( $cust_bill[1]->charged == $recur, "second bill is $recur" )
      or diag("second bill is ".$cust_bill[1]->charged);

  }
}
