package FS::part_pkg::flat_delayed;
use base qw(FS::part_pkg::delayed_Mixin FS::part_pkg::flat );

use strict;
use vars qw(%info);

%info = (
  'name' => 'Free (or setup fee) for X days, then flat rate'.
            ' (anniversary billing)',
  'shortname' => 'Anniversary, with intro period',
  'inherit_fields' => [qw( global_Mixin delayed_Mixin )],
  'fields' =>  {
    #shouldn't this be inherited from somewhere?
    'suspend_bill' => { 'name' => 'Continue recurring billing while suspended',
                        'type' => 'checkbox',
                      },
      },
  'fieldorder' => [ 'suspend_bill', ],
  'weight' => 12,
);

1;
