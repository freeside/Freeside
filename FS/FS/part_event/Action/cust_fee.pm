package FS::part_event::Action::cust_fee;

use strict;
use base qw( FS::part_event::Action::Mixin::fee );

sub description { 'Charge a fee based on the customer\'s current invoice'; }

sub eventtable_hashref {
    { 'cust_main'       => 1,
      'cust_pay_batch'  => 1 };
}

sub hold_until_bill { 1 }

# Otherwise identical to cust_bill_fee.  We only have a separate event 
# because it behaves differently as an invoice event than as a customer
# event, and needs a different description.

1;
