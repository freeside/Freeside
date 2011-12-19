package FS::svc_Tower_Mixin;

use strict;
use FS::Record qw(qsearchs); #qsearch;
use FS::tower_sector;

=item tower_sector

=cut

sub tower_sector {
  my $self = shift;
  return '' unless $self->sectornum;
  qsearchs('tower_sector', { sectornum => $self->sectornum });
}

1;
