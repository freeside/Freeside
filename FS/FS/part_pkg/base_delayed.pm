package FS::part_pkg::base_delayed;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::base_rate;

@ISA = qw(FS::part_pkg::base_rate);

%info = (
  'name' => 'Free (or setup fee) for X days, then base rate'.
            ' (anniversary billing)',
  'shortname' => 'Bulk (manual from "units" option), w/intro period',
  'inherit_fields' => [ 'global_Mixin' ],
  'fields' =>  {
    'free_days' => { 'name' => 'Initial free days',
                     'default' => 0,
                   },
    'recur_notify' => { 'name' => 'Number of days before recurring billing'.
                                  ' commences to notify customer. (0 means'.
                                  ' no warning)',
                     'default' => 0,
                    },
  },
  'fieldorder' => [ 'free_days', 'recur_notify',
                  ],
  #'setup' => '\'my $d = $cust_pkg->bill || $time; $d += 86400 * \' + what.free_days.value + \'; $cust_pkg->bill($d); $cust_pkg_mod_flag=1; \' + what.setup_fee.value',
  #'recur' => 'what.recur_fee.value',
  'weight' => 54, #&g!
);

sub calc_setup {
  my($self, $cust_pkg, $time ) = @_;

  my $d = $cust_pkg->bill || $time;
  $d += 86400 * $self->option('free_days');
  $cust_pkg->bill($d);
  
  $self->option('setup_fee');
}

1;
