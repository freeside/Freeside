package FS::part_event::Action::cust_statement;

use strict;

use base qw( FS::part_event::Action );

use FS::cust_statement;

sub description {
  'Group invoices into an informational statement.';
}

sub eventtable_hashref {
    { 'cust_main' => 1, };
    { 'cust_pkg'  => 1, };
}

sub default_weight {
  90;
}

sub do_action {
  my( $self, $cust_main ) = @_;

  #my( $self, $object ) = @_;
  #my $cust_main = $self->cust_main($object);

  my $cust_statement = new FS::cust_statement {
    'custnum' => $cust_main->custnum
  };
  my $error = $cust_statement->insert;
  die $error if $error;

  '';

}

1;
