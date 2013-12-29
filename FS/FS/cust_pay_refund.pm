package FS::cust_pay_refund;
use base qw(FS::Record);

use strict;
use FS::Record qw( qsearchs ); # qsearch );
use FS::cust_main;

#ask FS::UID to run this stuff for us later
#FS::UID->install_callback( sub { 
#  $conf = new FS::Conf;
#} );

=head1 NAME

FS::cust_pay_refund - Object methods for cust_pay_refund records

=head1 SYNOPSIS

  use FS::cust_pay_refund;

  $record = new FS::cust_pay_refund \%hash;
  $record = new FS::cust_pay_refund { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pay_refund object represents application of a refund (see
L<FS::cust_refund>) to an payment (see L<FS::cust_pay>).  FS::cust_pay_refund
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item payrefundnum - primary key

=item paynum - credit being applied 

=item refundnum - invoice to which credit is applied (see L<FS::cust_bill>)

=item amount - amount of the credit applied

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new cust_pay_refund.  To add the cust_pay_refund to the database,
see L<"insert">.

=cut

sub table { 'cust_pay_refund'; }

=item insert

Adds this cust_pay_refund to the database.  If there is an error, returns the
error, otherwise returns false.

=cut

sub insert {
  my $self = shift;
  return "Can't apply refund to closed payment"
    if $self->cust_pay->closed =~ /^Y/i;
  return "Can't apply payment to closed refund"
    if $self->cust_refund->closed =~ /^Y/i;
  $self->SUPER::insert(@_);
}

=item delete

=cut

sub delete {
  my $self = shift;
  return "Can't remove refund from closed payment"
    if $self->cust_pay->closed =~ /^Y/i;
  return "Can't remove payment from closed refund"
    if $self->cust_refund->closed =~ /^Y/i;
  $self->SUPER::delete(@_);
}

=item replace OLD_RECORD

Application of refunds to payments may not be modified.

=cut

sub replace {
  return "Can't modify application of a refund to payment!"
}

=item check

Checks all fields to make sure this is a valid refund application to a payment.
If there is an error, returns the error, otherwise returns false.  Called by
the insert and replace methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('payrefundnum')
    || $self->ut_number('paynum')
    || $self->ut_number('refundnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('amount')
  ;
  return $error if $error;

  return "amount must be > 0" if $self->amount <= 0;

  return "Unknown payment"
    unless my $cust_pay = 
      qsearchs( 'cust_pay', { 'paynum' => $self->paynum } );

  return "Unknown refund"
    unless my $cust_refund =
      qsearchs( 'cust_refund', { 'refundnum' => $self->refundnum } );

  $self->_date(time) unless $self->_date;

  return 'Cannot apply ($'. $self->amount. ') more than'.
         ' remaining value of refund ($'. $cust_refund->unapplied. ')'
    unless $self->amount <= $cust_refund->unapplied;

  return "Cannot apply more than remaining value of payment"
    unless $self->amount <= $cust_pay->unapplied;

  $self->SUPER::check;
}

=item sub cust_pay

Returns the payment (see L<FS::cust_pay>)

=item cust_refund

Returns the refund (see L<FS::cust_refund>)

=back

=head1 BUGS

The delete method.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_refund>, L<FS::cust_bill>, L<FS::cust_credit>,
schema.html from the base documentation.

=cut

1;

