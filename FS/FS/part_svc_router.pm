package FS::part_svc_router;

use strict;
use vars qw( @ISA );
use FS::Record qw(qsearchs);
use FS::router;
use FS::part_svc;

@ISA = qw(FS::Record);

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

sub router {
  my $self = shift;
  return qsearchs('router', { routernum => $self->routernum });
}

sub part_svc {
  my $self = shift;
  return qsearchs('part_svc', { svcpart => $self->svcpart });
}

1;
