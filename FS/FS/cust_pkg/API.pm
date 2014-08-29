package FS::cust_pkg::API;

use strict;

sub API_getinfo {
  my $self = shift;

  +{ ( map { $_=>$self->$_ } $self->fields ),
   };

}

1;
