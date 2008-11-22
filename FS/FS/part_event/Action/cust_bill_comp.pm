package FS::part_event::Action::cust_bill_comp;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Pay invoice with a complimentary "payment"'; }

sub deprecated { 1; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub default_weight { 30; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  my $error = $cust_bill->comp;
  die $error if $error;

  '';
}

1;
