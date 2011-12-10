package FS::tower;

use strict;
use base qw( FS::o2m_Common FS::Record );
use FS::Record qw( qsearch ); #qsearchs );
use FS::tower_sector;

=head1 NAME

FS::tower - Object methods for tower records

=head1 SYNOPSIS

  use FS::tower;

  $record = new FS::tower \%hash;
  $record = new FS::tower { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::tower object represents a tower.  FS::tower inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item towernum

primary key

=item towername

Tower name

=item disabled

Disabled flag, empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tower.  To add the tower to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'tower'; }

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

Checks all fields to make sure this is a valid tower.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('towernum')
    || $self->ut_text('towername')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item tower_sector

Returns the sectors of this tower, as FS::tower_sector objects (see
L<FS::tower_sector>).

=cut

sub tower_sector {
  my $self = shift;
  qsearch({
    'table'    => 'tower_sector',
    'hashref'  => { 'towernum' => $self->towernum },
    'order_by' => 'ORDER BY sectorname',
  });
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::tower_sector>, L<FS::svc_broadband>, L<FS::Record>

=cut

1;

