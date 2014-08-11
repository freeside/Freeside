package FS::deploy_zone_block;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::deploy_zone_block - Object methods for deploy_zone_block records

=head1 SYNOPSIS

  use FS::deploy_zone_block;

  $record = new FS::deploy_zone_block \%hash;
  $record = new FS::deploy_zone_block { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::deploy_zone_block object represents a census block that's part of
a deployment zone.  FS::deploy_zone_block inherits from FS::Record.  The 
following fields are currently supported:

=over 4

=item blocknum

primary key

=item zonenum

L<FS::deploy_zone> foreign key for the zone.

=item censusblock

U.S. census block number (15 digits).

=item censusyear

The year of the census map where the block appeared or was last verified.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new block entry.  To add the recordto the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'deploy_zone_block'; }

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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('blocknum')
    || $self->ut_number('zonenum')
    || $self->ut_number('censusblock')
    || $self->ut_number('censusyear')
  ;
  return $error if $error;

  if ($self->get('censusblock') !~ /^(\d{15})$/) {
    return "Illegal census block number (must be 15 digits)";
  }

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>

=cut

1;

