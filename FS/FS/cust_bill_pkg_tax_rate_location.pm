package FS::cust_bill_pkg_tax_rate_location;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::cust_bill_pkg;
use FS::cust_pkg;
use FS::cust_location;

=head1 NAME

FS::cust_bill_pkg_tax_rate_location - Object methods for cust_bill_pkg_tax_rate_location records

=head1 SYNOPSIS

  use FS::cust_bill_pkg_tax_rate_location;

  $record = new FS::cust_bill_pkg_tax_rate_location \%hash;
  $record = new FS::cust_bill_pkg_tax_rate_location { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg_tax_rate_location object represents an record of taxation
based on package location.  FS::cust_bill_pkg_tax_rate_location inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item billpkgtaxratelocationnum

billpkgtaxratelocationnum

=item billpkgnum

billpkgnum

=item taxnum

taxnum

=item taxtype

taxtype

=item locationtaxid

locationtaxid

=item taxratelocationnum

taxratelocationnum

=item amount

amount


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_bill_pkg_tax_rate_location'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('billpkgtaxratelocationnum')
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg', 'billpkgnum' )
    || $self->ut_number('taxnum') #cust_bill_pkg/tax_rate key, based on taxtype
    || $self->ut_enum('taxtype', [ qw( FS::cust_main_county FS::tax_rate ) ] )
    || $self->ut_textn('locationtaxid')
    || $self->ut_foreign_key('taxratelocationnum', 'tax_rate_location', 'taxratelocationnum' )
    || $self->ut_money('amount')
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

