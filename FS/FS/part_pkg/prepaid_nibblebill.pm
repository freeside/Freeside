package FS::part_pkg::prepaid_nibblebill;
use base qw( FS::part_pkg::flat );

use strict;
use vars qw(%info);

%info = (
  'name' => 'Prepaid credit in FreeSWITCH mod_nibblebill',
  #'name' => 'Prepaid (no automatic recurring)', #maybe use it here too
  'shortname' => 'Prepaid FreeSWITCH mod_nibblebill',
  #'inherit_fields' => [ 'global_Mixin' ],
  'fields' => {
    'setup_fee'   => { 'default' => 0, },
    'recur_fee'   => { 'default' => 0, },
    'nibble_rate' => { 'name' => 'Nibble rate' },
  },
  'fieldorder' => [ qw( setup_fee recur_fee nibble_rate ) ],
  'weight' => 49,
);

sub is_prepaid {
  1;
}

1;

