package FS::cust_bill_pkg_detail_void;

use strict;
use base qw( FS::Record );
use FS::Record; # qw( qsearch qsearchs );
use FS::cust_bill_pkg_void;
use FS::usage_class;

=head1 NAME

FS::cust_bill_pkg_detail_void - Object methods for cust_bill_pkg_detail_void records

=head1 SYNOPSIS

  use FS::cust_bill_pkg_detail_void;

  $record = new FS::cust_bill_pkg_detail_void \%hash;
  $record = new FS::cust_bill_pkg_detail_void { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg_detail_void object represents additional detail
information for a voided invoice line item.  FS::cust_bill_pkg_detail_void
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item detailnum

primary key

=item billpkgnum

billpkgnum

=item pkgnum

pkgnum

=item invnum

invnum

=item amount

amount

=item format

format

=item classnum

classnum

=item duration

duration

=item phonenum

phonenum

=item accountcode

accountcode

=item startdate

startdate

=item regionname

regionname

=item detail

detail


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_bill_pkg_detail_void'; }

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
    $self->ut_number('detailnum')
    || $self->ut_foreign_keyn('billpkgnum', 'cust_bill_pkg_void', 'billpkgnum')
    || $self->ut_numbern('pkgnum')
    || $self->ut_numbern('invnum')
    || $self->ut_floatn('amount')
    || $self->ut_enum('format', [ '', 'C' ] )
    || $self->ut_foreign_keyn('classnum', 'usage_class', 'classnum')
    || $self->ut_numbern('duration')
    || $self->ut_textn('phonenum')
    || $self->ut_textn('accountcode')
    || $self->ut_numbern('startdate')
    || $self->ut_textn('regionname')
    || $self->ut_text('detail')
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

