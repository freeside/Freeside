package FS::contact_Mixin;

use strict;
use FS::Record qw( qsearchs );
use FS::contact;

=item contact_obj

Returns the contact object, if any (see L<FS::contact>).

=cut

sub contact_obj {
  my $self = shift;
  return '' unless $self->contactnum;
  qsearchs( 'contact', { 'contactnum' => $self->contactnum } );
}

1;
