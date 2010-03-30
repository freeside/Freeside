package FS::part_event::Condition::balance;

use strict;
use FS::cust_main;

use base qw( FS::part_event::Condition );

sub description { 'Customer balance'; }

sub implicit_flag { 20; }

sub remove_warning {
  'Are you sure you want to remove this condition?  Doing so will allow this event to run even if the customer has no outstanding balance.  Perhaps you want to reset "Balance over" to 0 instead of removing the condition entirely?'; #better error msg?
}

sub option_fields {
  (
    'balance' => { 'label'      => 'Balance over',
                   'type'       => 'money',
                   'value'      => '0.00', #default
                 },
  );
}

sub condition {
  my($self, $object) = @_;

  my $cust_main = $self->cust_main($object);

  my $over = $self->option('balance');
  $over = 0 unless length($over);

  $cust_main->balance > $over;
}

sub condition_sql {
  my( $class, $table ) = @_;

  my $over = $class->condition_sql_option('balance');

  my $balance_sql = FS::cust_main->balance_sql;

  "$balance_sql > CAST( $over AS DECIMAL(10,2) )";

}

1;

