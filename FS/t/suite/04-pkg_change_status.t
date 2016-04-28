#!/usr/bin/perl

=head2 DESCRIPTION

Tests the effect of a scheduled change on the status of an active or
suspended package. Ref RT#38564.

Correct: A scheduled package change should result in a package with the same
status as before.

=cut

use strict;
use Test::More tests => 20;
use FS::Test;
use Date::Parse 'str2time';
use Test::MockTime qw(set_fixed_time);
use FS::cust_main;
use FS::cust_pkg;
my $FS = FS::Test->new;

# Create two package defs with the suspend_bill flag, and one with
# the unused_credit_change flag.
my $part_pkg = $FS->qsearchs('part_pkg', { pkgpart => 2 });
my $error;
my @part_pkgs;
foreach my $i (0, 1) {
  $part_pkgs[$i] = $part_pkg->clone;
  $part_pkgs[$i]->insert(options => { $part_pkg->options,
                                      'suspend_bill' => 1,
                                      'unused_credit_change' => $i } );
  BAIL_OUT("can't configure package: $error") if $error;
}

# For customer #3, order four packages. 0-1 will be suspended, 2-3 will not.
# 1 and 3 will use $part_pkgs[1], the one with unused_credit_change.

my $cust = $FS->qsearchs('cust_main', { custnum => 3 });
my @pkgs;
foreach my $i (0..3) {
  $pkgs[$i] = FS::cust_pkg->new({ pkgpart => $part_pkgs[$i % 2]->pkgpart });
  $error = $cust->order_pkg({ cust_pkg => $pkgs[$i] });
  BAIL_OUT("can't order package: $error") if $error;
}

# On Mar 25, bill the customer.

set_fixed_time(str2time('2016-03-25'));
$error = $cust->bill_and_collect;
ok( $error eq '', 'initially bill customer' );
# update our @pkgs to match
@pkgs = map { $_->replace_old } @pkgs;

# On Mar 26, suspend packages 0-1.

set_fixed_time(str2time('2016-03-25'));
my $reason_type = $FS->qsearchs('reason_type', { type => 'Suspend Reason' });
foreach my $i (0,1) {
  $error = $pkgs[$i]->suspend(reason => {
    typenum => $reason_type->typenum,
    reason  => 'Test suspension + future package change',
  });
  ok( $error eq '', "suspended package $i" ) or diag($error);
  $pkgs[$i] = $pkgs[$i]->replace_old;
}

# For each of these packages, clone the package def, then schedule a future
# change (on Mar 26) to that package.
my $change_date = str2time('2016-03-26');
my @new_pkgs;
foreach my $i (0..3) {
  my $pkg = $pkgs[$i];
  my $new_part_pkg = $pkg->part_pkg->clone;
  $error = $new_part_pkg->insert( options => { $pkg->part_pkg->options } );
  ok( $error eq '', 'created new package def' ) or diag($error);
  $error = $pkg->change_later(
    pkgpart     => $new_part_pkg->pkgpart,
    start_date  => $change_date,
  );
  ok( $error eq '', 'scheduled package change' ) or diag($error);
  $new_pkgs[$i] = $FS->qsearchs('cust_pkg', {
      pkgnum    => $pkg->change_to_pkgnum
  });
  ok( $new_pkgs[$i], 'future package was created' );
}

# Then bill the customer on that date.
set_fixed_time($change_date);
$error = $cust->bill_and_collect;
ok( $error eq '', 'billed customer on change date' ) or diag($error);

foreach my $i (0,1) {
  $new_pkgs[$i] = $new_pkgs[$i]->replace_old;
  ok( $new_pkgs[$i]->status eq 'suspended', "new package $i is suspended" )
    or diag($new_pkgs[$i]->status);
}
foreach my $i (2,3) {
  $new_pkgs[$i] = $new_pkgs[$i]->replace_old;
  ok( $new_pkgs[$i]->status eq 'active', "new package $i is active" )
    or diag($new_pkgs[$i]->status);
}

1;
