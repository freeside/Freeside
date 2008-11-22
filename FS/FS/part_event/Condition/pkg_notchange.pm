package FS::part_event::Condition::pkg_notchange;

use strict;

use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );

sub description {
  'Package is a new order, not a change';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 0,
      'cust_pkg'  => 1,
    };
}

sub condition {
  my( $self, $cust_pkg ) = @_;

  ! $cust_pkg->change_date;

}

sub condition_sql {
  '( cust_pkg.change_date IS NULL OR cust_pkg.change_date = 0 )';
}

1;

