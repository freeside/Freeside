package FS::quotation_pkg_tax;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::cust_main_county;
use FS::quotation_pkg;

=head1 NAME

FS::quotation_pkg_tax - Object methods for quotation_pkg_tax records

=head1 SYNOPSIS

  use FS::quotation_pkg_tax;

  $record = new FS::quotation_pkg_tax \%hash;
  $record = new FS::quotation_pkg_tax { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::quotation_pkg_tax object represents tax on a quoted package. 
FS::quotation_pkg_tax inherits from FS::Record (though it should eventually
inherit from some shared superclass of L<FS::cust_bill_pkg_tax_location>). 
The following fields are currently supported:

=over 4

=item quotationtaxnum - primary key

=item quotationpkgnum - the L<FS::quotation_pkg> record that the tax applies 
to.

=item itemdesc - the name of the tax

=item taxnum - the L<FS::cust_main_county> or L<FS::tax_rate> defining the 
tax.

=item taxtype - the class of the tax rate represented by C<taxnum>.

=item setup_amount - the amount of tax calculated on one-time charges

=item recur_amount - the amount of tax calculated on recurring charges

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new estimated tax amount.  To add the record to the database, 
see L<"insert">.

=cut

sub table { 'quotation_pkg_tax'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('quotationtaxnum')
    || $self->ut_foreign_key('quotationpkgnum', 'quotation_pkg', 'quotationpkgnum')
    || $self->ut_text('itemdesc')
    || $self->ut_number('taxnum')
    || $self->ut_enum('taxtype', [ 'FS::cust_main_county', 'FS::tax_rate' ])
    || $self->ut_money('setup_amount')
    || $self->ut_money('recur_amount')
  ;
  return $error if $error;

  $self->SUPER::check;
}

#stub for 3.x
sub quotation_pkg {
  my $self = shift;
  FS::quotation_pkg->by_key($self->quotationpkgnum);
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

