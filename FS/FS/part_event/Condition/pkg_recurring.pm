package FS::part_event::Condition::pkg_recurring;

use strict;

use base qw( FS::part_event::Condition );

sub description { 'Package is recurring'; }

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 0,
      'cust_pkg'  => 1,
    };
}

sub condition {
  my( $self, $cust_pkg ) = @_;

  $cust_pkg->part_pkg->freq !~ /^0+\D?$/; #just in case, probably just != '0'

}

sub condition_sql {
  FS::cust_pkg->recurring_sql()
}

1;

