package FS::part_event::Action::Mixin::credit_sales_pkg_class;
use base qw( FS::part_event::Action::Mixin::credit_pkg );

use strict;
use FS::Record qw(qsearchs);

sub option_fields {
  my $class = shift;
  my %option_fields = $class->SUPER::option_fields;

  delete $option_fields{'percent'};

  $option_fields{'cust_main_sales'} = {
    'label' => "Credit the customer sales person if there is no package sales person",
    'type'  => 'checkbox',
    'value' => 'Y',
  };

  %option_fields;
}

sub _calc_credit_percent {
  my( $self, $cust_pkg ) = @_;

  my $salesnum = $cust_pkg->salesnum;
  $salesnum ||= $self->cust_main($cust_pkg)->salesnum
    if $self->option('cust_main_sales');

  return 0 unless $salesnum;

  my $sales_pkg_class = qsearchs( 'sales_pkg_class', {
    'salesnum' => $salesnum,
    'classnum' => $cust_pkg->part_pkg->classnum,
  });

  $sales_pkg_class ? $sales_pkg_class->commission_percent : 0;

}

1;
