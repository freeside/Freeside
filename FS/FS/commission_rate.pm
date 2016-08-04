package FS::commission_rate;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::commission_rate - Object methods for commission_rate records

=head1 SYNOPSIS

  use FS::commission_rate;

  $record = new FS::commission_rate \%hash;
  $record = new FS::commission_rate { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::commission_rate object represents a commission rate (a percentage or a
flat amount) that will be paid on a customer's N-th invoice. The sequence of
commissions that will be paid on consecutive invoices is the parent object,
L<FS::commission_schedule>.

FS::commission_rate inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item commissionratenum - primary key

=item schedulenum - L<FS::commission_schedule> foreign key

=item cycle - the ordinal of the billing cycle this commission will apply
to. cycle = 1 applies to the customer's first invoice, cycle = 2 to the
second, etc.

=item amount - the flat amount to pay per invoice in commission

=item percent - the percentage of the invoice amount to pay in 
commission

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new commission rate.  To add it to the database, see L<"insert">.

=cut

sub table { 'commission_rate'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid commission rate.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  $self->set('amount', '0.00')
    if $self->get('amount') eq '';
  $self->set('percent', '0')
    if $self->get('percent') eq '';

  my $error = 
    $self->ut_numbern('commissionratenum')
    || $self->ut_number('schedulenum')
    || $self->ut_number('cycle')
    || $self->ut_money('amount')
    || $self->ut_decimal('percent')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>

=cut

1;

