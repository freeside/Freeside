package FS::part_event::Condition::cust_bill_owed_under;

use strict;
use FS::cust_bill;

use base qw( FS::part_event::Condition );

sub description {
  'Amount owed on specific invoice (under)';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

sub option_fields {
  (
    'owed' => { 'label'      => 'Amount owed under (or equal to)',
                'type'       => 'money',
                'value'      => '0.00', #default
              },
  );
}

sub condition {
  #my($self, $cust_bill, %opt) = @_;
  my($self, $cust_bill) = @_;

  my $under = $self->option('owed');
  $under = 0 unless length($under);

  $cust_bill->owed <= $under;

}

sub condition_sql {
  my( $class, $table ) = @_;
  
  my $under = $class->condition_sql_option('owed');

  my $owed_sql = FS::cust_bill->owed_sql;

  "$owed_sql <= CAST( $under AS numeric )";
}

1;
