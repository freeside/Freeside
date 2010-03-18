package FS::part_event::Condition::cust_bill_has_noauto;

use strict;
use FS::cust_bill;

use base qw( FS::part_event::Condition );

sub description {
  'Invoice ineligible for automatic collection';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

sub condition {
  #my($self, $cust_bill, %opt) = @_;
  my($self, $cust_bill) = @_;

  $cust_bill->no_auto;
}

#sub condition_sql {
#  my( $class, $table ) = @_;
#  
#  my $sql = qq|  |;
#  return $sql;
#}

1;
