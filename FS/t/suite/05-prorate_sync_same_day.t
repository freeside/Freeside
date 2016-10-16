#!/usr/bin/perl

=head2 DESCRIPTION

Tests the effect of ordering and activating two sync_bill_date packages on
the same day. Ref RT#42108.

Formerly correct: If the packages have prorate_round_day = 1 (round
nearest), or 3 (round down) then the second package should be prorated one
day short. If they have prorate_round_day = 2 (round up), they should be
billed for the same amount. In both cases they should have the same next
bill date.

Revised RT#72928: The second package should be prorated one day short only
if the rounding mode is 1 (round nearest), as the nearest day is different
for the two packages.

=cut

use strict;
use Test::More tests => 9;
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
      bill_location => $location,
      ship_location => $location,
  });
  $error = $cust->insert;
  BAIL_OUT("can't create test customer: $error") if $error;

  my @pkgs;
  # Create and bill the first package.
  set_fixed_time(str2time('2016-03-10 08:00'));
  $pkgs[0] = FS::cust_pkg->new({ pkgpart => $pkgpart });
  $error = $cust->order_pkg({ 'cust_pkg' => $pkgs[0] });
  BAIL_OUT("can't order package: $error") if $error;
  $error = $cust->bill_and_collect;
  # Check the amount billed.
  my ($cust_bill_pkg) = $pkgs[0]->cust_bill_pkg;
  my $recur = $part_pkg->base_recur;
  ok( $cust_bill_pkg->recur == $recur, "first package recur is $recur" )
    or diag("first package recur is ".$cust_bill_pkg->recur);

  # Create and bill the second package.
  set_fixed_time(str2time('2016-03-10 16:00'));
  $pkgs[1] = FS::cust_pkg->new({ pkgpart => $pkgpart });
  $error = $cust->order_pkg({ 'cust_pkg' => $pkgs[1] });
  BAIL_OUT("can't order package: $error") if $error;
  $error = $cust->bill_and_collect;

  # Check the amount billed.
  if ( $prorate_mode == 1 ) {
    # it should be one day short, in March
    $recur = sprintf('%.2f', $recur * 30/31);
  }
  ($cust_bill_pkg) = $pkgs[1]->cust_bill_pkg;
  ok( $cust_bill_pkg->recur == $recur, "second package recur is $recur" )
    or diag("second package recur is ".$cust_bill_pkg->recur);

  my @next_bill = map { time2str('%Y-%m-%d', $_->replace_old->get('bill')) } @pkgs;

  ok( $next_bill[0] eq $next_bill[1],
    "both packages will bill again on $next_bill[0]" )
    or diag("first package bill date is $next_bill[0], second package is $next_bill[1]");
}
