package FS::part_pkg_taxoverride;

use strict;
use vars qw( @ISA );
use FS::Record;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_pkg_taxoverride - Object methods for part_pkg_taxoverride records

=head1 SYNOPSIS

  use FS::part_pkg_taxoverride;

  $record = new FS::part_pkg_taxoverride \%hash;
  $record = new FS::part_pkg_taxoverride { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_taxoverride object represents a manual mapping of a
package to tax rates.  FS::part_pkg_taxoverride inherits from FS::Record.
The following fields are currently supported:

=over 4

=item taxoverridenum

Primary key

=item pkgpart

The package definition id

=item taxnum

The tax rate definition id

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax override.  To add the tax product to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'part_pkg_taxoverride'; }

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

Checks all fields to make sure this is a valid tax product.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('taxoverridenum')
    || $self->ut_foreign_key('pkgpart', 'part_pkg', 'pkgpart')
    || $self->ut_foreign_key('taxnum', 'tax_rate', 'taxnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=cut

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

