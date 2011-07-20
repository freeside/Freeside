package FS::part_event::Action::cust_bill_print;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Send invoice (print only)'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub default_weight { 51; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  $cust_bill->print;
}

1;
