package FS::part_pkg::prepaid;

use strict;
use vars qw(@ISA %info);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Prepaid, flat rate',
  'fields' => {
    'setup_fee' => { 'name' => 'One-time setup fee for this package',
                     'default' => 0,
                   },
    'recur_fee' => { 'name' => 'Initial and recharge fee for this package',
                     'default' => 0,
                   }
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee', ],
  'weight' => 25,
);

sub is_prepaid {
  1;
}

1;

