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

tie my %overlimit_action, 'Tie::IxHash',
  'overlimit' => 'Default overlimit processing',
  'cancel'    => 'Cancel',
;

%info = (
  'name' => 'Prepaid, flat rate',
  #'name' => 'Prepaid (no automatic recurring)', #maybe use it here too
  'shortname' => 'Prepaid, no automatic cycle',
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
    %FS::part_pkg::flat::usage_fields,
    'overlimit_action' => { 'name' => 'Action to take upon reaching a usage limit.',
                            'type' => 'select',
                            'select_options' => \%overlimit_action,
	              },
    #XXX if you set overlimit_action to 'cancel', should also have the ability
    # to select a reason
  },
  'fieldorder' => [ qw( setup_fee recur_fee recur_action ),
                    @FS::part_pkg::flat::usage_fieldorder,
                  ],
  'weight' => 25,
);

sub is_prepaid {
  1;
}

1;

