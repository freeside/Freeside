package FS::part_event::Action::collect;

use strict;
use base qw( FS::part_event::Action );

sub description {
  #'Collect on invoices (normally only used with a <i>Late Fee</i> and <i>Generate Invoice</i> events)';
  'Collect on invoices (normally only used with a Late Fee and Generate Invoice events)';
}

sub deprecated { 1; }

sub default_weight { 80; }

sub do_action {
  my( $self, $cust_object ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  my $error = $cust_main->collect;
  die $error if $error;

  '';
}

1;
