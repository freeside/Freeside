package FS::part_event::Condition::cust_bill_age;

use strict;
use base qw( FS::part_event::Condition );

sub description { 'Invoice age'; }

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

sub option_fields {
  (
    'age' => { label=>'Age', type=>'freq', },
  );
}

sub condition {
  my( $self, $cust_bill, %opt ) = @_;

  my $age = $self->option_age_from('age', $opt{'time'} );

  ( $cust_bill->_date - 60 ) <= $age;

}

sub condition_sql {
  my( $class, $table, %opt ) = @_;

  my $age  = $class->condition_sql_option_age_from('age', $opt{'time'} );

  "( cust_bill._date - 60 ) <= $age";
}

sub order_sql {
  shift->condition_sql_option_age('age');
}

sub order_sql_weight {
  0;
}

1;
