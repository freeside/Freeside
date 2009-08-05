package FS::part_pkg::prorate_delayed;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg;

@ISA = qw(FS::part_pkg::prorate);

%info = (
  'name' => 'Free (or setup fee) for X days, then prorate, then flat-rate ' .
         '(1st of month billing)',
  'shortname' => 'Prorate (Nth of month billing), with intro period', #??
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
                                  ' commences to notify customer. (0 means'.
                                  ' no warning)',
                     'default' => 0,
                    },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
  },
  'fieldorder' => [ 'free_days', 'setup_fee', 'recur_fee', 'unused_credit' ],
  #'setup' => '\'my $d = $cust_pkg->bill || $time; $d += 86400 * \' + what.free_days.value + \'; $cust_pkg->bill($d); $cust_pkg_mod_flag=1; \' + what.setup_fee.value',
  #'recur' => 'what.recur_fee.value',
  'weight' => 22,
);

sub calc_setup {
  my($self, $cust_pkg, $time ) = @_;

  my $d = $cust_pkg->bill || $time;
  $d += 86400 * $self->option('free_days');
  $cust_pkg->bill($d);
  
  $self->option('setup_fee');
}

sub calc_remain {
  my ($self, $cust_pkg, %options) = @_;
  my $next_bill = $cust_pkg->getfield('bill') || 0;
  my $last_bill = $cust_pkg->last_bill || 0;
  my $free_days = $self->option('free_days');

  return 0 if    $last_bill + (86400 * $free_days) == $next_bill
              && $last_bill == $cust_pkg->setup;

  return 0 if    ! $self->base_recur($cust_pkg)
              || ! $self->option('unused_credit', 1)
              || ! $last_bill
              || ! $next_bill;

  return $self->SUPER::calc_remain($cust_pkg, %options);
}

1;
