package FS::part_event::Action::cust_bill_fee;

use strict;
use base qw( FS::part_event::Action::Mixin::fee );

sub description { 'Charge a fee based on this invoice'; }

sub eventtable_hashref {
    { 'cust_bill' => 1 };
}

1;
