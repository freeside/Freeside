package FS::part_svc_router;
use base qw(FS::Record);

use strict;

sub table { 'part_svc_router'; }

sub check {
  my $self = shift;
  my $error =
       $self->ut_numbern('svcrouternum')
    || $self->ut_foreign_key('svcpart', 'part_svc', 'svcpart')
    || $self->ut_foreign_key('routernum', 'router', 'routernum');
  return $error if $error;
  ''; #no error
}

1;
