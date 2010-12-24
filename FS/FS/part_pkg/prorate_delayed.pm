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
  'fieldorder' => [ 'free_days', 'recur_notify' ],
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
  my $last_bill = $cust_pkg->last_bill || 0;
  my $next_bill = $cust_pkg->getfield('bill') || 0;
  my $free_days = $self->option('free_days');

  return 0 if    $last_bill + (86400 * $free_days) == $next_bill
              && $last_bill == $cust_pkg->setup;

  return $self->SUPER::calc_remain($cust_pkg, %options);
}

1;
