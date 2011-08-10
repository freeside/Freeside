package FS::part_pkg::prorate_delayed;
use base qw( FS::part_pkg::delayed_Mixin FS::part_pkg::prorate );

use strict;
use vars qw(%info);

%info = (
  'name' => 'Free (or setup fee) for X days, then prorate, then flat-rate ' .
         '(1st of month billing)',
  'shortname' => 'Prorate (Nth of month billing), with intro period', #??
  'inherit_fields' => [qw( global_Mixin delayed_Mixin )],
  'fields' =>  {
    #shouldn't this be inherited from somewhere?
    'suspend_bill' => { 'name' => 'Continue recurring billing while suspended',
                        'type' => 'checkbox',
                      },
  },
  'fieldorder' => [ 'suspend_bill', ],
  'weight' => 22,
);

1;
