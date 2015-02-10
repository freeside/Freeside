package FS::part_event::Condition::hasnt_cust_payby_auto;

use strict;
use Tie::IxHash;

use base qw( FS::part_event::Condition );

sub description {
  'Customer does not have automatic payment information';
}

sub condition {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  ! scalar( qsearch({ 
    'table'     => 'cust_payby',
    'hashref'   => { 'custnum' => $cust_main->custnum,
                   },
    'extra_sql' => "AND payby IN ( 'CARD', 'CHEK' )",
    'order_by'  => 'LIMIT 1',
  }) );

}

1;
