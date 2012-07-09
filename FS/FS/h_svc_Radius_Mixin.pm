package FS::h_svc_Radius_Mixin;

use strict;
use FS::Record qw( qsearch );
use FS::h_radius_usergroup;

sub h_usergroup {
  my $self = shift;
  map { $_->groupnum } 
    qsearch( 'h_radius_usergroup',
             { svcnum => $self->svcnum },
             FS::h_radius_usergroup->sql_h_searchs(@_),
           );
}

1;

