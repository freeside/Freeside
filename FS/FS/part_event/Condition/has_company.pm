package FS::part_event::Condition::has_company;
use base qw( FS::part_event::Condition );

use strict;

sub description { 'Customer is commercial'; }

sub condition {
  my( $self, $object) = @_;                                                     
                                                                                
  my $cust_main = $self->cust_main($object);

  $cust_main->company =~ /\S/;
}

1;
