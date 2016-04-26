#!/usr/bin/perl

use FS::Test;
use Test::More tests => 6;
use Test::MockTime 'set_fixed_time';
use Date::Parse 'str2time';
use FS::cust_main;

my $FS = FS::Test->new;

# After test 01: cust#2 has a package set to bill on 2016-03-20.
# Set local time.
my $date = '2016-03-20';
set_fixed_time(str2time($date));
my $cust_main = FS::cust_main->by_key(2);
my @return;

# Bill the customer.
my $error = $cust_main->bill( return_bill => \@return );
ok($error eq '', "billed on $date") or diag($error);

# should be an invoice now
my $cust_bill = $return[0];
isa_ok($cust_bill, 'FS::cust_bill');

# $60/month * (30 days - 19 days)/30 days = $42
ok( $cust_bill->charged == 42.00, 'prorated first month correctly' );

# the package bill date should now be 2016-04-01
my @lineitems = $cust_bill->cust_bill_pkg;
ok( scalar(@lineitems) == 1, 'one package was billed' );
my $pkg = $lineitems[0]->cust_pkg;
ok( $pkg->status eq 'active', 'package is now active' );
ok( $pkg->bill == str2time('2016-04-01'), 'package bill date set correctly' );

1;
