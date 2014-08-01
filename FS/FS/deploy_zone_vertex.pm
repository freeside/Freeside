package FS::deploy_zone_vertex;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::deploy_zone_vertex - Object methods for deploy_zone_vertex records

=head1 SYNOPSIS

  use FS::deploy_zone_vertex;

  $record = new FS::deploy_zone_vertex \%hash;
  $record = new FS::deploy_zone_vertex { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::deploy_zone_vertex object represents a vertex of a polygonal 
deployment zone (L<FS::deploy_zone>).  FS::deploy_zone_vertex inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item vertexnum

primary key

=item zonenum

Foreign key to L<FS::deploy_zone>.

=item latitude

Latitude, as a decimal; positive values are north of the Equator.

=item longitude

Longitude, as a decimal; positive values are east of Greenwich.

=item sequence

The ordinal position of this vertex, starting with zero.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new vertex record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'deploy_zone_vertex'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid vertex.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('vertexnum')
    || $self->ut_number('zonenum')
    || $self->ut_coord('latitude')
    || $self->ut_coord('longitude')
    || $self->ut_number('sequence')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

