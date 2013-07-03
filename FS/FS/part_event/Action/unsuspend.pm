package FS::part_event::Action::unsuspend;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Unsuspend all of this customer\'s suspended packages'; }

sub default_weight { 11; }

sub do_action {
  my( $self, $cust_object ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  my @err = $cust_main->unsuspend();

  die join(' / ', @err) if scalar(@err);

  '';

}

1;
