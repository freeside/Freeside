package FS::part_event::Action::pkg_fee;

use strict;
use base qw( FS::part_event::Action::Mixin::fee );

sub description { 'Charge a fee when this package is billed'; }

sub eventtable_hashref {
    { 'cust_pkg' => 1 };
}

sub hold_until_bill { 1 }

# Functionally identical to cust_fee.

1;
