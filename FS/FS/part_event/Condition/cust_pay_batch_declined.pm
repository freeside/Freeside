package FS::part_event::Condition::cust_pay_batch_declined;

use strict;

use base qw( FS::part_event::Condition );

sub description {
  'Batch payment declined';
}

sub eventtable_hashref {
    { 'cust_main'      => 0,
      'cust_bill'      => 0,
      'cust_pkg'       => 0,
      'cust_pay_batch' => 1,
    };
}

sub condition {
  my($self, $cust_pay_batch, %opt) = @_;

  $cust_pay_batch->status =~ /Declined/i;
}

sub condition_sql {
  my( $class, $table ) = @_;

  "(cust_pay_batch.status IS NOT NULL AND cust_pay_batch.status = 'Declined')";
}

1;
