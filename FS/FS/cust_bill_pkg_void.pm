package FS::cust_bill_pkg_void;

use strict;
use base qw( FS::Record );
use FS::Record; # qw( qsearch qsearchs );

=head1 NAME

FS::cust_bill_pkg_void - Object methods for cust_bill_pkg_void records

=head1 SYNOPSIS

  use FS::cust_bill_pkg_void;

  $record = new FS::cust_bill_pkg_void \%hash;
  $record = new FS::cust_bill_pkg_void { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg_void object represents a voided invoice line item.
FS::cust_bill_pkg_void inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item billpkgnum

primary key

=item invnum

invnum

=item pkgnum

pkgnum

=item pkgpart_override

pkgpart_override

=item setup

setup

=item recur

recur

=item sdate

sdate

=item edate

edate

=item itemdesc

itemdesc

=item itemcomment

itemcomment

=item section

section

=item freq

freq

=item quantity

quantity

=item unitsetup

unitsetup

=item unitrecur

unitrecur

=item hidden

hidden


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_bill_pkg_void'; }

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
    $self->ut_number('billpkgnum')
    || $self->ut_snumber('pkgnum')
    || $self->ut_number('invnum') #cust_bill or cust_bill_void ?
    || $self->ut_numbern('pkgpart_override')
    || $self->ut_money('setup')
    || $self->ut_money('recur')
    || $self->ut_numbern('sdate')
    || $self->ut_numbern('edate')
    || $self->ut_textn('itemdesc')
    || $self->ut_textn('itemcomment')
    || $self->ut_textn('section')
    || $self->ut_textn('freq')
    || $self->ut_numbern('quantity')
    || $self->ut_moneyn('unitsetup')
    || $self->ut_moneyn('unitrecur')
    || $self->ut_enum('hidden', [ '', 'Y' ])
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

