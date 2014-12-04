package FS::part_event::Action::bill_sales_credit_pkg_class;

use base qw( FS::part_event::Action::Mixin::pkg_sales_credit
             FS::part_event::Action::Mixin::credit_bill
             FS::part_event::Action::Mixin::credit_sales_pkg_class
             FS::part_event::Action::bill_sales_credit
             );

sub description { "Credit the sales person based on their commission percentage for the package's class"; }

1;
