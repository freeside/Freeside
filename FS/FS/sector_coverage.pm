package FS::sector_coverage;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );
use Cpanel::JSON::XS;

=head1 NAME

FS::sector_coverage - Object methods for sector_coverage records

=head1 SYNOPSIS

  use FS::sector_coverage;

  $record = new FS::sector_coverage \%hash;
  $record = new FS::sector_coverage { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::sector_coverage object represents a coverage map for a sector at
a specific signal strength level.  FS::sector_coverage inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item coveragenum

primary key

=item sectornum

L<FS::tower_sector> foreign key

=item db_loss

The maximum path loss shown on this map, in dB.

=item geometry

A GeoJSON Geometry object for the area covered at this level.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new map.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'sector_coverage'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

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
    $self->ut_numbern('coveragenum')
    || $self->ut_number('sectornum')
    || $self->ut_number('db_loss')
  ;
  return $error if $error;

  if ( length($self->geometry) ) {
    # make sure it parses at least
    local $@;
    my $data = eval { decode_json($self->geometry) };
    if ( $@ ) {
      # limit the length, in case it decides to return a large chunk of data
      return "Error parsing coverage geometry: ".substr($@, 0, 100);
    }
  }

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

