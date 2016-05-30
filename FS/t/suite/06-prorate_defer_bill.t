#!/usr/bin/perl

=head2 DESCRIPTION

Tests the prorate_defer_bill behavior when a package is started on the cutoff day,
and when it's started later in the month.

Correct: The package started on the cutoff day should be charged a setup fee and a
full period. The package started later in the month should be charged a setup fee,
a full period, and the partial period.

=cut

use strict;
use Test::More tests => 11;
use FS::Test;
use Date::Parse 'str2time';
use Date::Format 'time2str';
use Test::MockTime qw(set_fixed_time);
use FS::cust_main;
use FS::cust_pkg;
use FS::Conf;
my $FS= FS::Test->new;

my $error;

my $old_part_pkg = $FS->qsearchs('part_pkg', { pkgpart => 2 });
my $part_pkg = $old_part_pkg->clone;
BAIL_OUT("existing pkgpart 2 is not a prorated monthly package")
  unless $part_pkg->freq eq '1' and $part_pkg->plan eq 'prorate';
$error = $part_pkg->insert(
  options => {  $old_part_pkg->options,
                'prorate_defer_bill' => 1,
                'cutoff_day' => 1,
                'setup_fee'  => 100,
                'recur_fee'  => 30,
              }
);
BAIL_OUT("can't configure package: $error") if $error;

my $cust = $FS->new_customer('Prorate defer');
$error = $cust->insert;
BAIL_OUT("can't create test customer: $error") if $error;

my @pkgs;
foreach my $start_day (1, 11) {
  diag("prorate package starting on day $start_day");
  # Create and bill the first package.
  my $date = str2time("2016-04-$start_day");
  set_fixed_time($date);
  my $pkg = FS::cust_pkg->new({ pkgpart => $part_pkg->pkgpart });
  $error = $cust->order_pkg({ 'cust_pkg' => $pkg });
  BAIL_OUT("can't order package: $error") if $error;

  # bill the customer on the order date
  $error = $cust->bill_and_collect;
  $pkg = $pkg->replace_old;
  push @pkgs, $pkg;
  my ($cust_bill_pkg) = $pkg->cust_bill_pkg;
  if ( $start_day == 1 ) {
    # then it should bill immediately
    ok($cust_bill_pkg, "package was billed") or next;
    ok($cust_bill_pkg->setup == 100, "setup fee was charged");
    ok($cust_bill_pkg->recur == 30, "one month was charged");
  } elsif ( $start_day == 11 ) {
    # then not
    ok(!$cust_bill_pkg, "package billing was deferred");
    ok($pkg->setup == $date, "package setup date was set");
  }
}
diag("first of month billing...");
my $date = str2time('2016-05-01');
set_fixed_time($date);
my @bill;
$error = $cust->bill_and_collect(return_bill => \@bill);
# examine the invoice...
my $cust_bill = $bill[0] or BAIL_OUT("neither package was billed");
for my $pkg ($pkgs[0]) {
  diag("package started day 1:");
  my ($cust_bill_pkg) = grep {$_->pkgnum == $pkg->pkgnum} $cust_bill->cust_bill_pkg;
  ok($cust_bill_pkg, "was billed") or next;
  ok($cust_bill_pkg->setup == 0, "no setup fee was charged");
  ok($cust_bill_pkg->recur == 30, "one month was charged");
}
for my $pkg ($pkgs[1]) {
  diag("package started day 11:");
  my ($cust_bill_pkg) = grep {$_->pkgnum == $pkg->pkgnum} $cust_bill->cust_bill_pkg;
  ok($cust_bill_pkg, "was billed") or next;
  ok($cust_bill_pkg->setup == 100, "setup fee was charged");
  ok($cust_bill_pkg->recur == 50, "twenty days + one month was charged");
}

