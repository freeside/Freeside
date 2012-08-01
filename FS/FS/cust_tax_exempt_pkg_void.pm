package FS::cust_tax_exempt_pkg_void;

use strict;
use base qw( FS::Record );
use FS::Record; # qw( qsearch qsearchs );
use FS::cust_bill_pkg_void;
use FS::cust_main_county;

=head1 NAME

FS::cust_tax_exempt_pkg_void - Object methods for cust_tax_exempt_pkg_void records

=head1 SYNOPSIS

  use FS::cust_tax_exempt_pkg_void;

  $record = new FS::cust_tax_exempt_pkg_void \%hash;
  $record = new FS::cust_tax_exempt_pkg_void { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_tax_exempt_pkg_void object represents a voided record of a customer
tax exemption.  FS::cust_tax_exempt_pkg_void inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item exemptpkgnum

primary key

=item billpkgnum

billpkgnum

=item taxnum

taxnum

=item year

year

=item month

month

=item creditbillpkgnum

creditbillpkgnum

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

sub table { 'cust_tax_exempt_pkg_void'; }

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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_number('exemptpkgnum')
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg_void', 'billpkgnum' )
    || $self->ut_foreign_key('taxnum', 'cust_main_county', 'taxnum')
    || $self->ut_number('year')
    || $self->ut_number('month')
    || $self->ut_numbern('creditbillpkgnum') #no FK check, will have been del'ed
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

