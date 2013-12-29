package FS::cust_bill_pay_batch;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::cust_bill_pay_batch - Object methods for cust_bill_pay_batch records

=head1 SYNOPSIS

  use FS::cust_bill_pay_batch;

  $record = new FS::cust_bill_pay_batch \%hash;
  $record = new FS::cust_bill_pay_batch { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pay_batch object represents a relationship between a
customer's bill and a batch.  FS::cust_bill_pay_batch inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item billpaynum - primary key

=item invnum - customer's bill (invoice)

=item paybatchnum - entry in cust_pay_batch table

=item amount - 

=item _date - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_bill_pay_batch'; }

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

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('billpaynum')
    || $self->ut_number('invnum')
    || $self->ut_number('paybatchnum')
    || $self->ut_money('amount')
    || $self->ut_numbern('_date')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

Just hangs there.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

