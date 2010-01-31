package FS::part_pkg::sesmon_hour;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Base charge plus charge per-hour from the session monitor',
  'shortname' => 'Session monitor (per-hour)',
  'fields' => {
    'setup_fee' => { 'name' => 'Setup fee for this package',
                     'default' => 0,
                   },
    'recur_fee' => { 'name' => 'Base recurring fee for this package',
                     'default' => 0,
                   },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
    'recur_included_hours' => { 'name' => 'Hours included',
                                'default' => 0,
                              },
    'recur_hourly_charge' => { 'name' => 'Additional charge per hour',
                               'default' => 0,
                             },
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee', 'unused_credit', 'recur_included_hours', 'recur_hourly_charge' ],
  #'setup' => 'what.setup_fee.value',
  #'recur' => '\'my $hours = $cust_pkg->seconds_since($cust_pkg->bill || 0) / 3600 - \' + what.recur_included_hours.value + \'; $hours = 0 if $hours < 0; \' + what.recur_fee.value + \' + \' + what.recur_hourly_charge.value + \' * $hours;\'',
  'weight' => 80,
);

sub calc_recur {
  my($self, $cust_pkg ) = @_;

  my $hours = $cust_pkg->seconds_since($cust_pkg->bill || 0) / 3600;
  $hours -= $self->option('recur_included_hours');
  $hours = 0 if $hours < 0;

  $self->option('recur_fee') + $hours * $self->option('recur_hourly_charge');

}

sub can_discount { 0; }

sub is_free_options {
  qw( setup_fee recur_fee recur_hourly_charge );
}

sub base_recur {
  my($self, $cust_pkg) = @_;
  $self->option('recur_fee');
}

1;
