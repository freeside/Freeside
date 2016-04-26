#!/usr/bin/perl

use Test::More tests => 4;
use FS::Test;
use Date::Parse 'str2time';
my $FS = FS::Test->new;

# get the form
$FS->post('/misc/order_pkg.html', custnum => 2);
my $form = $FS->form('OrderPkgForm');

# Customer #2 has three packages:
# a $30 monthly prorate, a $90 monthly prorate, and a $25 annual prorate.
# Next bill date on the monthly prorates is 2016-04-01.
# Add a new package that will start billing on 2016-03-20 (to make prorate
# behavior visible).

my %params = (
  pkgpart                 => 2,
  quantity                => 1,
  start                   => 'on_date',
  start_date              => '03/20/2016',
  package_comment0        => $0, # record the test we're executing
);

$form->find_input('start')->disabled(0); # JS
foreach (keys %params) {
  $form->value($_, $params{$_});
}
$FS->post($form);
ok( $FS->error eq '' , 'form posted' );
if (
   ok( $FS->page =~ m[location = '.*/view/cust_main.cgi.*\#cust_pkg(\d+)'],
      'new package accepted' )
) {
 # on success, sends us back to cust_main view with #cust_pkg$pkgnum
  # but with an in-page javascript redirect
  my $pkg = $FS->qsearchs('cust_pkg', { pkgnum => $1 });
  isa_ok( $pkg, 'FS::cust_pkg' );
  ok($pkg->start_date == str2time('2016-03-20'), 'start date set');
} else {
  # try to display the error message, or if not, show everything
  $FS->post($FS->redirect);
  diag ($FS->error);
  done_testing(2);
}

1;

