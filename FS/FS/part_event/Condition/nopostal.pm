package FS::part_event::Condition::nopostal;
use base qw( FS::part_event::Condition );
use strict;

sub description {
  'Customer does not receive a postal mail invoice';
}

sub condition {
  my( $self, $object ) = @_;
  my $cust_main = $self->cust_main($object);

  $cust_main->postal_invoice eq '';
}

sub condition_sql {
  my( $self, $table ) = @_;

  " cust_main.postal_invoice IS NULL ";
}

1;
