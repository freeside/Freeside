package FS::cust_credit_bill;

use strict;
use vars qw( @ISA );
use FS::UID qw( getotaker );
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::cust_refund;
use FS::cust_credit;
use FS::cust_bill;

@ISA = qw( FS::Record );

=head1 NAME

FS::cust_credit_bill - Object methods for cust_credit_bill records

=head1 SYNOPSIS

  use FS::cust_credit_bill;

  $record = new FS::cust_credit_bill \%hash;
  $record = new FS::cust_credit_bill { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_credit_bill object represents application of a credit (see
L<FS::cust_credit>) to a customer bill (see L<FS::cust_bill>).  FS::cust_credit
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item crednum - primary key; credit being applied 

=item invnum - invoice to which credit is applied (see L<FS::cust_bill>)

=item amount - amount of the credit applied

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new cust_credit_bill.  To add the cust_credit_bill to the database,
see L<"insert">.

=cut

sub table { 'cust_credit_bill'; }

=item insert

Adds this cust_credit_bill to the database ("Posts" all or part of a credit).
If there is an error, returns the error, otherwise returns false.

=item delete

Currently unimplemented.

=cut

sub delete {
  return "Can't unapply credit!"
}

=item replace OLD_RECORD

Application of credits may not be modified.

=cut

sub replace {
  return "Can't modify application of credit!"
}

=item check

Checks all fields to make sure this is a valid credit application.  If there
is an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_number('crednum')
    || $self->ut_number('invnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('amount')
  ;
  return $error if $error;

  return "Unknown credit"
    unless my $cust_credit = 
      qsearchs( 'cust_credit', { 'crednum' => $self->crednum } );

  return "Unknown invoice"
    unless my $cust_bill =
      qsearchs( 'cust_bill', { 'invnum' => $self->invnum } );

  $self->_date(time) unless $self->_date;

  return "Cannot apply more than remaining value of credit memo"
    unless $self->amount <= $cust_credit->credited;

  return "Cannot apply more than remaining value of invoice"
    unless $self->amount <= $cust_bill->owed;

  ''; #no error
}

=back

=head1 VERSION

$Id: cust_credit_bill.pm,v 1.1 2001-09-01 21:52:19 jeff Exp $

=head1 BUGS

The delete method.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_refund>, L<FS::cust_bill>, schema.html from the base
documentation.

=cut

1;

