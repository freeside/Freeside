package FS::part_pkg_discount;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::discount;
use FS::part_pkg;

=head1 NAME

FS::part_pkg_discount - Object methods for part_pkg_discount records

=head1 SYNOPSIS

  use FS::part_pkg_discount;

  $record = new FS::part_pkg_discount \%hash;
  $record = new FS::part_pkg_discount { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_discount object represents a link from a package definition
to a discount.  This permits discounts for lengthened terms.  FS::part_pkg_discount inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item pkgdiscountnum

primary key

=item pkgpart

pkgpart

=item discountnum

discountnum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new part_pkg_discount.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'part_pkg_discount'; }

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

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('pkgdiscountnum')
    || $self->ut_number('pkgpart')
    || $self->ut_number('discountnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item discount

Returns the discount associated with this part_pkg_discount.

=cut

sub discount {
  my $self = shift;
  qsearch('discount', { 'discountnum' => $self->discountnum });
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

