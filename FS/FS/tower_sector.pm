package FS::tower_sector;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::tower_sector - Object methods for tower_sector records

=head1 SYNOPSIS

  use FS::tower_sector;

  $record = new FS::tower_sector \%hash;
  $record = new FS::tower_sector { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::tower_sector object represents an tower sector.  FS::tower_sector
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item sectornum

primary key

=item towernum

towernum

=item sectorname

sectorname

=item ip_addr

ip_addr


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new sector.  To add the sector to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'tower_sector'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  #not the most efficient, not not awful, and its not like deleting a sector
  # with customers is a common operation
  return "Can't delete a sector with customers" if $self->svc_broadband;

  $self->SUPER::delete;
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid sector.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('sectornum')
    || $self->ut_number('towernum', 'tower', 'towernum')
    || $self->ut_text('sectorname')
    || $self->ut_textn('ip_addr')
    || $self->ut_floatn('height')
    || $self->ut_numbern('freq_mhz')
    || $self->ut_numbern('direction')
    || $self->ut_numbern('width')
    || $self->ut_floatn('range')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item tower

Returns the tower for this sector, as an FS::tower object (see L<FS::tower>).

=item description

Returns a description for this sector including tower name.

=cut

sub description {
  my $self = shift;
  if ( $self->sectorname eq '_default' ) {
    $self->tower->towername
  }
  else {
    $self->tower->towername. ' sector '. $self->sectorname
  }
}

=item svc_broadband

Returns the services on this tower sector.

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::tower>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

