package FS::part_event::Action::cust_statement_send;

use strict;

use base qw( FS::part_event::Action );

sub description {
  'Send statement (email/print/fax)';
}

sub eventtable_hashref {
  { 'cust_statement' => 1, };
}

sub default_weight {
  95;
}

sub do_action {
  my( $self, $cust_statement ) = @_;

  $cust_statement->send( 'statement' ); #XXX configure

}

1;
