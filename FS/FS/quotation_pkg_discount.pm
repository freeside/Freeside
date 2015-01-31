package FS::quotation_pkg_discount;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::Maketext 'mt';

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

quotationpkgnum of the L<FS::quotation_pkg> record that this discount is
for.

=item discountnum

discountnum (L<FS::discount>)

=item setup_amount

Amount that will be discounted from setup fees, per package quantity.

=item recur_amount

Amount that will be discounted from recurring fees in the first billing
cycle, per package quantity.

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
    || $self->ut_moneyn('setup_amount')
    || $self->ut_moneyn('recur_amount')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=item amount

Returns the total amount of this discount (setup + recur), for compatibility
with L<FS::cust_bill_pkg_discount>.

=cut

sub amount {
  my $self = shift;
  return $self->get('setup_amount') + $self->get('recur_amount');
}

=item description

Returns a string describing the discount (for use on the quotation).

=cut

sub description {
  my $self = shift;
  my $discount = $self->discount;
  my $desc = $discount->description_short;
  # XXX localize to prospect language, once prospects get languages
  $desc .= mt(' each') if $self->quotation_pkg->quantity > 1;

  if ($discount->months) {
    # unlike cust_bill_pkg_discount, there are no "months remaining"; it 
    # hasn't started yet.
    $desc .= mt(' (for [quant,_1,month])', $discount->months);
  }
  return $desc;
}

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

