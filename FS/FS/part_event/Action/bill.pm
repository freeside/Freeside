package FS::part_event::Action::bill;

use strict;
use base qw( FS::part_event::Action );

sub description {
  #'Generate invoices (normally only used with a <i>Late Fee</i> event)';
  'Generate invoices (normally only used with a Late Fee event)';
}

sub deprecated { 1; }

sub default_weight { 60; }

sub do_action {
  my( $self, $cust_object ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  my $error = $cust_main->bill;
  die $error if $error;

  '';
}

1;
