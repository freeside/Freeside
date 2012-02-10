package FS::tower_sector;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearchs ); # qsearch );
use FS::tower;

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

An FS::tower_sector object represents an example.  FS::tower_sector inherits from
FS::Record.  The following fields are currently supported:

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

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'tower_sector'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('sectornum')
    || $self->ut_number('towernum', 'tower', 'towernum')
    || $self->ut_text('sectorname')
    || $self->ut_textn('ip_addr')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item tower

Returns the tower for this sector, as an FS::tower object (see L<FS::tower>).

=cut

sub tower {
  my $self = shift;
  qsearchs('tower', { 'towernum'=>$self->towernum } );
}

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

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::tower>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

