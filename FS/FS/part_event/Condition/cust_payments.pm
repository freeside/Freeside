package FS::part_event::Condition::cust_payments;

use strict;
use base qw( FS::part_event::Condition );

sub description { 'Customer total payments'; }

sub option_fields {
  (
    'over' => { 'label'      => 'Customer total payments at least',
                'type'       => 'money',
                'value'      => '0.00', #default
              },
  );
}

sub condition {
  my($self, $object) = @_;

  my $cust_main = $self->cust_main($object);

  my $over = $self->option('over');
  $over = 0 unless length($over);

  $cust_main->total_paid >= $over;

}

#XXX add for efficiency.  could use cust_main::total_paid_sql
#use FS::cust_main;
#sub condition_sql {
#  my( $class, $table ) = @_;
#
#  my $over = $class->condition_sql_option('balance');
#
#  my $balance_sql = FS::cust_main->balance_sql;
#
#  "$balance_sql > $over";
#
#}

1;

