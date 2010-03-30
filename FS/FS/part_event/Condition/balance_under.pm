package FS::part_event::Condition::balance_under;

use strict;
use FS::cust_main;

use base qw( FS::part_event::Condition );

sub description { 'Customer balance (under)'; }

sub option_fields {
  (
    'balance' => { 'label'      => 'Balance under (or equal to)',
                   'type'       => 'money',
                   'value'      => '0.00', #default
                 },
  );
}

sub condition {
  my($self, $object) = @_;

  my $cust_main = $self->cust_main($object);

  my $under = $self->option('balance');
  $under = 0 unless length($under);

  $cust_main->balance <= $under;
}

sub condition_sql {
  my( $class, $table ) = @_;

  my $under = $class->condition_sql_option('balance');

  my $balance_sql = FS::cust_main->balance_sql;

  "$balance_sql <= CAST( $under AS DECIMAL(10,2) )";

}

1;

