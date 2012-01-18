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

=item tower_sector_sql HASHREF

Class method which returns a list of WHERE clause fragments to 
search for services with tower/sector given by HASHREF.  Can 
contain 'towernum' and 'sectornum' keys, either of which can be 
an arrayref or a single value.  To use this, the search needs to
join to tower_sector.

towernum or sectornum can also contain 'none' to allow null values.

=cut

sub tower_sector_sql {
  my $class = shift;
  my $params = shift;
  return '' unless keys %$params;
  my $where = '';

  my @where;
  for my $field (qw(towernum sectornum)) {
    my $value = $params->{$field} or next;
    if ( ref $value and grep { $_ } @$value ) {
      my $in = join(',', map { /^(\d+)$/ ? $1 : () } @$value);
      my @orwhere;
      push @orwhere, "tower_sector.$field IN ($in)" if $in;
      push @orwhere, "tower_sector.$field IS NULL" if grep /^none$/, @$value;
      push @where, '( '.join(' OR ', @orwhere).' )';
    }
    elsif ( $value =~ /^(\d+)$/ ) {
      push @where, "tower_sector.$field = $1";
    }
    elsif ( $value eq 'none' ) {
      push @where, "tower_sector.$field IS NULL";
    }
  }
  @where;
}


1;
