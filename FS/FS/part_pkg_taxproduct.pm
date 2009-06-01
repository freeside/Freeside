package FS::part_pkg_taxproduct;

use strict;
use vars qw( @ISA $delete_kludge );
use FS::Record qw( qsearch );

@ISA = qw(FS::Record);
$delete_kludge = 0;

=head1 NAME

FS::part_pkg_taxproduct - Object methods for part_pkg_taxproduct records

=head1 SYNOPSIS

  use FS::part_pkg_taxproduct;

  $record = new FS::part_pkg_taxproduct \%hash;
  $record = new FS::part_pkg_taxproduct { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_taxproduct object represents a tax product. 
FS::part_pkg_taxproduct inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item taxproductnum

Primary key

=item data_vendor

Tax data vendor

=item taxproduct

Tax product id from the vendor

=item description

A human readable description of the id in taxproduct

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax product.  To add the tax product to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'part_pkg_taxproduct'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  return "Can't delete a tax product which has attached package tax rates!"
    if qsearch( 'part_pkg_taxrate', { 'taxproductnum' => $self->taxproductnum } );

  unless ( $delete_kludge ) {
    return "Can't delete a tax product which has attached packages!"
      if qsearch( 'part_pkg', { 'taxproductnum' => $self->taxproductnum } );
  }

  $self->SUPER::delete(@_);
}

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
    $self->ut_numbern('taxproductnum')
    || $self->ut_textn('data_vendor')
    || $self->ut_text('taxproduct')
    || $self->ut_textn('description')
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

