package FS::part_pkg::API;

use strict;

sub API_getinfo {
  my $self = shift;
  #my( $self, %opt ) = @_;

  +{ ( map { $_=>$self->$_ } $self->fields ),
     ( map { $_=>$self->option($_) }
         qw(setup_fee recur_fee)
     ),
   };

}

1;
