package FS::part_pkg_vendor;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::part_pkg_vendor - Object methods for part_pkg_vendor records

=head1 SYNOPSIS

  use FS::part_pkg_vendor;

  $record = new FS::part_pkg_vendor \%hash;
  $record = new FS::part_pkg_vendor { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_vendor object represents a mapping of pkgpart numbers to
external package numbers.  FS::part_pkg_vendor inherits from FS::Record. 
The following fields are currently supported:

=over 4

=item num

primary key

=item pkgpart

pkgpart

=item exportnum

exportnum

=item vendor_pkg_id

vendor_pkg_id


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_pkg_vendor'; }

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
    $self->ut_numbern('num')
    || $self->ut_foreign_key('pkgpart', 'part_pkg', 'pkgpart')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum')
    || $self->ut_textn('vendor_pkg_id')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_export

Returns the L<FS::part_export> associated with this vendor/external package id.

=cut
sub part_export {
    my $self = shift;
    qsearchs( 'part_export', { 'exportnum' => $self->exportnum } );
}

=back

=head1 SEE ALSO

L<FS::part_pkg>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

