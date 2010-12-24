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
  'inherit_fields' => [ 'usage_Mixin', 'global_Mixin' ],
  'fields' => {
    'recur_action' => { 'name' => 'Action to take upon reaching end of prepaid preiod',
                        'type' => 'select',
			'select_options' => \%recur_action,
	              },
    'overlimit_action' => { 'name' => 'Action to take upon reaching a usage limit.',
                            'type' => 'select',
                            'select_options' => \%overlimit_action,
	              },
    #XXX if you set overlimit_action to 'cancel', should also have the ability
    # to select a reason
    
    # do we need to disable these?
    map { $_ => { 'disabled' => 1 } } (
      qw(recharge_amount recharge_seconds recharge_upbytes recharge_downbytes
      recharge_totalbytes usage_rollover recharge_reset) ),
  },
  'fieldorder' => [ qw( recur_action overlimit_action ) ],
  'weight' => 25,
);

sub is_prepaid {
  1;
}

1;

