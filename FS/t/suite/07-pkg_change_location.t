#!/usr/bin/perl

=head2 DESCRIPTION

Test scheduling a package location change through the UI, then billing
on the day of the scheduled change.

=cut

use Test::More tests => 6;
use FS::Test;
use Date::Parse 'str2time';
use Date::Format 'time2str';
use Test::MockTime qw(set_fixed_time);
use FS::cust_pkg;
my $FS = FS::Test->new;
my $error;

# set up a customer with an active package
my $cust = $FS->new_customer('Future location change');
$error = $cust->insert;
my $pkg = FS::cust_pkg->new({pkgpart => 2});
$error ||= $cust->order_pkg({ cust_pkg => $pkg });
my $date = str2time('2016-04-01');
set_fixed_time($date);
$error ||= $cust->bill_and_collect;
BAIL_OUT($error) if $error;

# get the form
my %args = ( pkgnum  => $pkg->pkgnum,
             pkgpart => $pkg->pkgpart,
             locationnum => -1);
$FS->post('/misc/change_pkg.cgi', %args);
my $form = $FS->form('OrderPkgForm');

# Schedule the package change two days from now.
$date += 86400*2;
my $date_str = time2str('%x', $date);

my %params = (
  start_date              => $date_str,
  delay                   => 1,
  address1                => int(rand(1000)) . ' Changed Street',
  city                    => 'New City',
  state                   => 'CA',
  zip                     => '90001',
  country                 => 'US',
);

diag "requesting location change to $params{address1}";

foreach (keys %params) {
  $form->value($_, $params{$_});
}
$FS->post($form);
ok( $FS->error eq '' , 'form posted' );
if ( ok( $FS->page =~ m[location.reload], 'location change accepted' )) {
  #nothing
} else {
  $FS->post($FS->redirect);
  BAIL_OUT( $FS->error);
}
# check that the package change is set
$pkg = $pkg->replace_old;
my $new_pkgnum = $pkg->change_to_pkgnum;
ok( $new_pkgnum, 'package change is scheduled' );

# run it and check that the package change happened
diag("billing customer on $date_str");
set_fixed_time($date);
my $error = $cust->bill_and_collect;
BAIL_OUT($error) if $error;

$pkg = $pkg->replace_old;
ok($pkg->get('cancel'), "old package is canceled");
my $new_pkg = $FS->qsearchs('cust_pkg', { pkgnum => $new_pkgnum });
ok($new_pkg->setup, "new package is active");
ok($new_pkg->cust_location->address1 eq $params{'address1'}, "new location is correct")
  or diag $new_pkg->cust_location->address1;

1;

