package FS::cust_bill_pkg_discount;

use strict;
use base qw( FS::cust_main_Mixin FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::cust_bill_pkg;
use FS::cust_pkg_discount;

=head1 NAME

FS::cust_bill_pkg_discount - Object methods for cust_bill_pkg_discount records

=head1 SYNOPSIS

  use FS::cust_bill_pkg_discount;

  $record = new FS::cust_bill_pkg_discount \%hash;
  $record = new FS::cust_bill_pkg_discount { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg_discount object represents the slice of a customer
applied to a line item.  FS::cust_bill_pkg_discount inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item billpkgdiscountnum

primary key

=item billpkgnum

Line item (see L<FS::cust_bill_pkg>)

=item pkgdiscountnum

Customer discount (see L<FS::cust_pkg_discount>)

=item amount

Amount discounted from the line itme.

=item months

Number of months of discount this represents.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_bill_pkg_discount'; }

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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('billpkgdiscountnum')
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg', 'billpkgnum' )
    || $self->ut_foreign_key('pkgdiscountnum', 'cust_pkg_discount', 'pkgdiscountnum' )
    || $self->ut_money('amount')
    || $self->ut_float('months')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item cust_bill_pkg

Returns the associated line item (see L<FS::cust_bill_pkg>).

=cut

sub cust_bill_pkg {
  my $self = shift;
  qsearchs( 'cust_bill_pkg', { 'billpkgnum' => $self->billpkgnum } ) ;
}

=item cust_pkg_discount

Returns the associated customer discount (see L<FS::cust_pkg_discount>).

=cut

sub cust_pkg_discount {
  my $self = shift;
  qsearchs( 'cust_pkg_discount', { 'pkgdiscountnum' => $self->pkgdiscountnum });
}


=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

