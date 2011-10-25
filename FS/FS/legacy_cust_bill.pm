package FS::legacy_cust_bill;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;

=head1 NAME

FS::legacy_cust_bill - Object methods for legacy_cust_bill records

=head1 SYNOPSIS

  use FS::legacy_cust_bill;

  $record = new FS::legacy_cust_bill \%hash;
  $record = new FS::legacy_cust_bill { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::legacy_cust_bill object represents an invoice from a previous billing
system, about which full details are not availble.  Instead, the rendered
content is stored in HTML or PDF format.  FS::legacy_cust_bill invoices are
stored for informational and display purposes only; they have no effect upon
customer balances.

FS::legacy_cust_bill inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item legacyinvnum

primary key

=item legacyid

Invoice number or identifier from previous system

=item custnum

Customer (see L<FS::cust_main)

=item _date

Date, as a UNIX timestamp

=item charged

Amount charged

=item content_pdf

PDF content

=item content_html

HTML content


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new legacy invoice.  To add the example to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'legacy_cust_bill'; }

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

Checks all fields to make sure this is a valid legacy invoice.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('legacyinvnum')
    || $self->ut_textn('legacyid')
    || $self->ut_foreign_keyn('custnum', 'cust_main', 'custnum')
    || $self->ut_number('_date')
    || $self->ut_money('charged')
    || $self->ut_anything('content_pdf')
    || $self->ut_anything('content_html')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item cust_main

Returns the customer (see L<FS::cust_main>) for this invoice.

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

