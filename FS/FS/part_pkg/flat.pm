package FS::part_pkg::flat;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch);
use FS::part_pkg;

@ISA = qw(FS::part_pkg);

%info = (
  'name' => 'Flat rate (anniversary billing)',
  'fields' => {
    'setup_fee' => { 'name' => 'Setup fee for this package',
                     'default' => 0,
                   },
    'recur_fee' => { 'name' => 'Recurring fee for this package',
                     'default' => 0,
                    },
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee' ],
  #'setup' => 'what.setup_fee.value',
  #'recur' => 'what.recur_fee.value',
  'weight' => 10,
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

sub calc_recur {
  my($self, $cust_pkg ) = @_;
  $self->option('recur_fee');
}

sub is_free_options {
  qw( setup_fee recur_fee );
}

1;
