package FS::quotation_pkg_discount;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::quotation_pkg_discount - Object methods for quotation_pkg_discount records

=head1 SYNOPSIS

  use FS::quotation_pkg_discount;

  $record = new FS::quotation_pkg_discount \%hash;
  $record = new FS::quotation_pkg_discount { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::quotation_pkg_discount object represents a quotation package discount.
FS::quotation_pkg_discount inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item quotationpkgdiscountnum

primary key

=item quotationpkgnum

quotationpkgnum

=item discountnum

discountnum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new quotation package discount.  To add the quotation package
discount to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'quotation_pkg_discount'; }

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

Checks all fields to make sure this is a valid quotation package discount.
If there is an error, returns the error, otherwise returns false.
Called by the insert and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('quotationpkgdiscountnum')
    || $self->ut_foreign_key('quotationpkgnum', 'quotation_pkg', 'quotationpkgnum' )
    || $self->ut_foreign_key('discountnum', 'discount', 'discountnum' )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

