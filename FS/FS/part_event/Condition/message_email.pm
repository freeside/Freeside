package FS::part_event::Condition::message_email;
use base qw( FS::part_event::Condition );
use strict;

sub description {
  'Customer allows email notices'
}

sub condition {
  my( $self, $object ) = @_;
  my $cust_main = $self->cust_main($object);

  $cust_main->message_noemail ? 0 : 1;
}

sub condition_sql {
  my( $self, $table ) = @_;

  "cust_main.message_noemail IS NULL"
}

1;
