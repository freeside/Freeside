package FS::part_event::Condition::cust_bill_owed;

use strict;
use FS::cust_bill;

use base qw( FS::part_event::Condition );

sub description {
  'Amount owed on specific invoice';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

sub option_fields {
  (
    'owed' => { 'label'      => 'Amount owed over',
                'type'       => 'money',
                'value'      => '0.00', #default
              },
  );
}

sub condition {
  #my($self, $cust_bill, %opt) = @_;
  my($self, $cust_bill) = @_;

  my $over = $self->option('owed');
  $over = 0 unless length($over);

  $cust_bill->owed > $over;
}

sub condition_sql {
  my( $class, $table ) = @_;
  
  my $over = $class->condition_sql_option('owed');

  my $owed_sql = FS::cust_bill->owed_sql;

  "$owed_sql > $over";
}

1;
