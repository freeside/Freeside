package FS::Mason::StandaloneRequest;

use strict;
use warnings;
use base 'FS::Mason::Request';

sub new {
  my $class = shift;

  $class->alter_superclass('HTML::Mason::Request');

  #huh... shouldn't alter_superclass take care of this for us?
  __PACKAGE__->valid_params( %{ HTML::Mason::Request->valid_params() } );

  my %opt = @_;
  #its already been altered# $class->freeside_setup($opt{'comp'}, 'standalone');
  FS::Mason::Request->freeside_setup($opt{'comp'}, 'standalone');

  $class->SUPER::new(@_);

}

1;
