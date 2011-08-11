package FS::part_pkg::delayed_Mixin;
use base qw( FS::part_pkg );

use strict;
use vars qw(%info);

%info = (
  'disabled' => 1,
  'fields' => {
    'free_days' => { 'name' => 'Initial free days',
                     'default' => 0,
                   },
    'delay_setup' => { 'name' => 'Delay setup fee in addition to recurring fee',
                       'type' => 'checkbox',
                     },
    'recur_notify' => { 'name' => 'Number of days before recurring billing'.
                                  ' commences to notify customer. (0 means'.
                                  ' no warning)',
                     'default' => 0,
                    },
  },
  'fieldorder' => [ 'free_days', 'delay_setup', 'recur_notify', ],
);

sub calc_setup {
  my($self, $cust_pkg, $time ) = @_;

  unless ( $self->option('delay_setup', 1) ) {
    my $d = $cust_pkg->bill || $time;
    $d += 86400 * $self->option('free_days');
    $cust_pkg->bill($d);
  }
  
  $self->option('setup_fee');
}

sub calc_remain {
  my ($self, $cust_pkg, %options) = @_;

  unless ( $self->option('delay_setup', 1) ) {
    my $last_bill = $cust_pkg->last_bill || 0;
    my $next_bill = $cust_pkg->getfield('bill') || 0;
    my $free_days = $self->option('free_days');

    return 0 if    $last_bill + (86400 * $free_days) == $next_bill
                && $last_bill == $cust_pkg->setup;
  }

  return $self->SUPER::calc_remain($cust_pkg, %options);
}

sub can_start_date { ! shift->option('delay_setup', 1) }

1;
