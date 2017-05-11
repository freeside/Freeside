package FS::part_event::Condition::hasnt_company;
use base qw( FS::part_event::Condition );

use strict;

sub description { 'Customer is residential'; }

sub condition {
  my( $self, $object) = @_;                                                     
                                                                                
  my $cust_main = $self->cust_main($object);

  $cust_main->company !~ /\S/;

}

1;
