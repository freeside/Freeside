package FS::part_event::Condition::inactive_age;

use strict;
use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );

sub description { 'Days without billing activity' }

sub option_fields {
  (
    'age'  =>  { 'label'   => 'No activity within',
                 'type'    => 'freq',
               },
    # flags to select kinds of activity, 
    # like if you just want "no payments since"?
    # not relevant yet
  );
}

sub condition {
  my( $self, $obj, %opt ) = @_;
  my $custnum = $obj->custnum;
  my $age = $self->option_age_from('age', $opt{'time'} );

  foreach my $t (qw(cust_bill cust_pay cust_credit cust_refund)) {
    my $class = "FS::$t";
    return 0 if $class->count("custnum = $custnum AND _date >= $age");
  }
  1;
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;
  my $age   = $class->condition_sql_option_age_from('age', $opt{'time'});
  my @sql;
  for my $t (qw(cust_bill cust_pay cust_credit cust_refund)) {
    push @sql,
      "NOT EXISTS( SELECT 1 FROM $t ".
      "WHERE $t.custnum = cust_main.custnum AND $t._date >= $age".
      ")";
  }
  join(' AND ', @sql);
}

1;

