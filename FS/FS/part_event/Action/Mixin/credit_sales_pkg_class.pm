package FS::part_event::Action::Mixin::credit_sales_pkg_class;

use strict;
use FS::Record qw(qsearchs);
use FS::sales_pkg_class;

sub _calc_credit_percent {
  my( $self, $cust_pkg, $sales ) = @_;

  die "sales record required" unless $sales;

  my $sales_pkg_class = qsearchs( 'sales_pkg_class', {
    'salesnum' => $sales->salesnum,
    'classnum' => $cust_pkg->part_pkg->classnum,
  });

  $sales_pkg_class ? $sales_pkg_class->commission_percent : 0;

}

1;
