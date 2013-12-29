package FS::cust_credit_refund;
use base qw( FS::cust_main_Mixin FS::Record );

use strict;

=head1 NAME

FS::cust_credit_refund - Object methods for cust_bill_pay records

=head1 SYNOPSIS 

  use FS::cust_credit_refund;

  $record = new FS::cust_credit_refund \%hash;
  $record = new FS::cust_credit_refund { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_credit_refund represents the application of a refund to a specific
credit.  FS::cust_credit_refund inherits from FS::Record.  The following fields
are currently supported:

=over 4

=item creditrefundnum - primary key (assigned automatically)

=item crednum - Credit (see L<FS::cust_credit>)

=item refundnum - Refund (see L<FS::cust_refund>)

=item amount - Amount of the refund to apply to the specific credit.

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=back

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'cust_credit_refund'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;
  return "Can't apply refund to closed credit"
    if $self->cust_credit->closed =~ /^Y/i;
  return "Can't apply credit to closed refund"
    if $self->cust_refund->closed =~ /^Y/i;
  $self->SUPER::insert(@_);
}

=item delete

Remove this cust_credit_refund from the database.  If there is an error, 
returns the error, otherwise returns false.

=cut

sub delete {
  my $self = shift;
  return "Can't remove refund from closed credit"
    if $self->cust_credit->closed =~ /^Y/i;
  return "Can't remove credit from closed refund"
    if $self->cust_refund->closed =~ /^Y/i;
  $self->SUPER::delete(@_);
}

=item replace OLD_RECORD

Currently unimplemented (accounting reasons).

=cut

sub replace {
   return "Can't (yet?) modify cust_credit_refund records!";
}

=item check

Checks all fields to make sure this is a valid refund application.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
method.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('creditrefundnum')
    || $self->ut_number('crednum')
    || $self->ut_number('refundnum')
    || $self->ut_money('amount')
    || $self->ut_numbern('_date')
  ;
  return $error if $error;

  return "amount must be > 0" if $self->amount <= 0;

  return "unknown cust_credit.crednum: ". $self->crednum
    unless my $cust_credit = $self->cust_credit;

  return "Unknown refund"
    unless my $cust_refund = $self->cust_refund;

  $self->_date(time) unless $self->_date;

  return "Cannot apply more than remaining value of credit"
    unless $self->amount <= $cust_credit->credited;

  return "Cannot apply more than remaining value of refund"
    unless $self->amount <= $cust_refund->unapplied;

  $self->SUPER::check;
}

=item cust_refund

Returns the refund (see L<FS::cust_refund>)

=item cust_credit

Returns the credit (see L<FS::cust_credit>)

=back

=head1 BUGS

Delete and replace methods.

the checks for over-applied refunds could be better done like the ones in
cust_bill_credit

=head1 SEE ALSO

L<FS::cust_credit>, L<FS::cust_refund>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

