package FS::part_pkg::flat_delayed;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Free (or setup fee) for X days, then flat rate'.
            ' (anniversary billing)',
  'fields' =>  {
    'setup_fee' => { 'name' => 'Setup fee for this package',
                     'default' => 0,
                   },
    'free_days' => { 'name' => 'Initial free days',
                     'default' => 0,
                   },
    'recur_fee' => { 'name' => 'Recurring fee for this package',
                     'default' => 0,
                    },
    'recur_notify' => { 'name' => 'Number of days before recurring billing'.
                                  'commences to notify customer. (0 means '.
                                  'no warning)',
                     'default' => 0,
                    },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
  },
  'fieldorder' => [ 'free_days', 'setup_fee', 'recur_fee', 'recur_notify',
                    'unused_credit'
                  ],
  #'setup' => '\'my $d = $cust_pkg->bill || $time; $d += 86400 * \' + what.free_days.value + \'; $cust_pkg->bill($d); $cust_pkg_mod_flag=1; \' + what.setup_fee.value',
  #'recur' => 'what.recur_fee.value',
  'weight' => 50,
);

sub calc_setup {
  my($self, $cust_pkg, $time ) = @_;

  my $d = $cust_pkg->bill || $time;
  $d += 86400 * $self->option('free_days');
  $cust_pkg->bill($d);
  
  $self->option('setup_fee');
}

1;
