package FS::part_pkg::delayed_Mixin;

use strict;
use vars qw(%info);
use Time::Local qw(timelocal);
use NEXT;

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
  my $self = shift;
  my( $cust_pkg, $time ) = @_;

  unless ( $self->option('delay_setup', 1) ) {
    my $d = $cust_pkg->bill || $time;
    $d += 86400 * $self->option('free_days');
    $cust_pkg->bill($d);
  }
  
  $self->NEXT::calc_setup(@_);
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

  return $self->NEXT::calc_remain($cust_pkg, %options);
}

sub can_start_date { ! shift->option('delay_setup', 1) }

sub default_start_date {
  my $self = shift;
  if ( $self->option('delay_setup') and $self->option('free_days') ) {
    my $delay = $self->option('free_days');

    my ($mday, $mon, $year) = (localtime(time))[3,4,5];
    return timelocal(0,0,0,$mday,$mon,$year) + 86400 * $self->option('free_days');
  }
  return $self->NEXT::default_start_date(@_);
}

1;
