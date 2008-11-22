package FS::part_event::Action::cust_bill_batch;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Add card or check to a pending batch'; }

sub deprecated { 1; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub default_weight { 40; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  $cust_bill->batch_card; # ( %options ); #XXX options??
}

1;
