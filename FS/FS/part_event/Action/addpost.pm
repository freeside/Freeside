package FS::part_event::Action::addpost;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Add postal invoicing'; }

sub default_weight { 20; }

sub do_action {
  my( $self, $cust_object ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  $cust_main->invoicing_list_addpost();

  '';
}

1;
