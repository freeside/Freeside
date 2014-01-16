package FS::part_event::Condition::cust_class;
use base qw( FS::part_event::Condition );

use strict;

sub description {
  'Customer class';
}

sub option_fields {
  (
    'cust_class'  => { 'label'    => 'Customer Class',
                       'type'     => 'select-cust_class',
                       'multiple' => 1,
                     },
  );
}

sub condition {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  my $hashref = $self->option('cust_class') || {};
  
  $hashref->{ $cust_main->classnum };
}

1;
