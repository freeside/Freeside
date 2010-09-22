package FS::part_event::Condition::balance_credit_limit;

use strict;
use FS::cust_main;

use base qw( FS::part_event::Condition );

sub description { 'Customer is over credit limit'; }

sub condition {
  my($self, $object) = @_;

  my $cust_main = $self->cust_main($object);

  my $over = $cust_main->credit_limit;
  return 0 if !length($over); # if credit limit is null, no limit

  $cust_main->balance > $over;
}

sub condition_sql {
  my( $class, $table ) = @_;

  my $balance_sql = FS::cust_main->balance_sql;

  "(cust_main.credit_limit IS NULL OR
    $balance_sql - cust_main.credit_limit > 0 )";

}

1;

