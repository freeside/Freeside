package FS::part_event::Condition::cust_bill_owed_percent;

use strict;
use FS::cust_bill;

use base qw( FS::part_event::Condition );

sub description {
  'Percentage owed on specific invoice';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

sub option_fields {
  (
    'owed' => { 'label'      => 'Percentage of invoice owed over',
                'type'       => 'percentage',
                'value'      => '0', #default
              },
  );
}

sub condition {
  #my($self, $cust_bill, %opt) = @_;
  my($self, $cust_bill) = @_;

  my $percent = $self->option('owed') || 0;
  my $over = sprintf('%.2f',
      $cust_bill->charged * $percent / 100);

  $cust_bill->owed > $over;
}

sub condition_sql {
  my( $class, $table ) = @_;

  # forces the option to be an integer--do we care?
  my $percent = $class->condition_sql_option_integer('owed');

  my $owed_sql = FS::cust_bill->owed_sql;

  "$owed_sql > CAST( cust_bill.charged * $percent / 100 AS DECIMAL(10,2) )";
}

1;
