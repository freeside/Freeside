package FS::part_pkg::prepaid;

use strict;
use vars qw(@ISA %info %recur_action);
use Tie::IxHash;
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

tie %recur_action, 'Tie::IxHash',
  'suspend' => 'suspend',
  'cancel'  => 'cancel',
;

%info = (
  'name' => 'Prepaid, flat rate',
  'fields' => {
    'setup_fee'   =>  { 'name' => 'One-time setup fee for this package',
                        'default' => 0,
                      },
    'recur_fee'   =>  { 'name' => 'Initial and recharge fee for this package',
                        'default' => 0,
                      },
    'recur_action' => { 'name' => 'Action to take upon reaching end of prepaid preiod',
                        'type' => 'select',
			'select_options' => \%recur_action,
	              },
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee', 'recur_action', ],
  'weight' => 25,
);

sub is_prepaid {
  1;
}

1;

