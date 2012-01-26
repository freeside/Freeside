package FS::part_pkg::global_Mixin;

use strict;
use vars qw(%info);

%info = (
  'disabled' => 1,
  'fields' => {
    'setup_fee' => { 
      'name' => 'Setup fee for this package',
      'default' => 0,
    },
    'recur_fee' => { 
      'name' => 'Recurring fee for this package',
      'default' => 0,
    },
    'unused_credit_cancel' => {
      'name' => 'Credit the customer for the unused portion of service at '.
                 'cancellation',
      'type' => 'checkbox',
    },
    'unused_credit_suspend' => {
      'name' => 'Credit the customer for the unused portion of service when '.
                'suspending',
      'type' => 'checkbox',
    },
    'unused_credit_change' => {
      'name' => 'Credit the customer for the unused portion of service when '.
                'changing packages',
      'type' => 'checkbox',
    },
  },
  'fieldorder' => [ qw(
    setup_fee
    recur_fee
    unused_credit_cancel
    unused_credit_suspend
    unused_credit_change
  )],
);

1;
