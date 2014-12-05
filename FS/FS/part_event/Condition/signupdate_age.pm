package FS::part_event::Condition::signupdate_age;
use base qw( FS::part_event::Condition );

use strict;

sub description { 'Customer signup age'; }

#lots of falze laziness w/cust_bill_age, basically just swapped out the field

sub option_fields {
  (
    'age' => { label=>'Age', type=>'freq', },
  );
}

sub condition {
  my( $self, $cust_bill, %opt ) = @_;

  my $age = $self->option_age_from('age', $opt{'time'} );

  ( $cust_main->signupdate - 60 ) <= $age;

}

sub condition_sql {
  my( $class, $table, %opt ) = @_;

  my $age  = $class->condition_sql_option_age_from('age', $opt{'time'} );

  "( cust_main.signupdate - 60 ) <= $age";
}

# i don't think it really matters what order, since we're a customer condition?
#  this is for ordering different events for a customer
sub order_sql {
  shift->condition_sql_option_age('age');
}

sub order_sql_weight {
  -1;
}

1;
1;
