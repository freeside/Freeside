package FS::Quotable_Mixin;

use strict;
use FS::Record qw( qsearch ); #qsearchs );
use FS::quotation;

sub quotation {
  my $self = shift;
  my $pk = $self->primary_key;
  qsearch('quotation', { $pk => $self->$pk() } );
}

1;
