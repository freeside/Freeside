package FS::CGIwrapper;

use vars qw(@ISA);

use CGI;

@ISA = qw( CGI );

sub header {
  my $self = shift;
  $self->SUPER::header(
    @_,
    '-expires'       => 'now',
    '-pragma'        => 'No-Cache',
    '-cache-control' => 'No-Cache',
  );
}
