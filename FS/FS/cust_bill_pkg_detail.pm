package FS::cust_bill_pkg_detail;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::cust_bill_pkg_detail - Object methods for cust_bill_pkg_detail records

=head1 SYNOPSIS

  use FS::cust_bill_pkg_detail;

  $record = new FS::cust_bill_pkg_detail \%hash;
  $record = new FS::cust_bill_pkg_detail { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg_detail object represents additional detail information for
an invoice line item (see L<FS::cust_bill_pkg>).  FS::cust_bill_pkg_detail
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item detailnum - primary key

=item pkgnum -

=item invnum -

=item detail - detail description

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new line item detail.  To add the line item detail to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_bill_pkg_detail'; }

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

Checks all fields to make sure this is a valid line item detail.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  $self->ut_numbern('detailnum')
    || $self->ut_foreign_key('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_foreign_key('invnum', 'cust_bill', 'invnum')
    || $self->ut_enum('format', [ '', 'C' ] )
    || $self->ut_text('detail')
    || $self->SUPER::check
    ;

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_bill_pkg>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

