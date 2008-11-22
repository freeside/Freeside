package FS::part_event::Action::apply;

use strict;
use base qw( FS::part_event::Action );

sub description {
  'Apply unapplied payments and credits';
}

sub deprecated { 1; }

sub default_weight { 70; }

sub do_action {
  my( $self, $cust_object ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  $cust_main->apply_payments_and_credits;

  '';
}

1;
