package FS::cust_bill_pay;

use strict;
use vars qw( @ISA $conf );
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_bill;
use FS::cust_pay;

@ISA = qw( FS::Record );

#ask FS::UID to run this stuff for us later
FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
} );

=head1 NAME

FS::cust_bill_pay - Object methods for cust_bill_pay records

=head1 SYNOPSIS 

  use FS::cust_bill_pay;

  $record = new FS::cust_bill_pay \%hash;
  $record = new FS::cust_bill_pay { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pay object represents the application of a payment to a
specific invoice.  FS::cust_bill_pay inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item billpaynum - primary key (assigned automatically)

=item invnum - Invoice (see L<FS::cust_bill>)

=item paynum - Payment (see L<FS::cust_pay>)

=item amount - Amount of the payment to apply to the specific invoice.

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=back

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'cust_bill_pay'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this payment application, unless the closed flag for the parent payment
(see L<FS::cust_pay>) is set.

=cut

sub delete {
  my $self = shift;
  return "Can't delete application for closed payment"
    if $self->cust_pay->closed =~ /^Y/i;
  $self->SUPER::delete(@_);
}

=item replace OLD_RECORD

Currently unimplemented (accounting reasons).

=cut

sub replace {
   return "Can't (yet?) modify cust_bill_pay records!";
}

=item check

Checks all fields to make sure this is a valid payment.  If there is an error,
returns the error, otherwise returns false.  Called by the insert method.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('billpaynum')
    || $self->ut_number('invnum')
    || $self->ut_number('paynum')
    || $self->ut_money('amount')
    || $self->ut_numbern('_date')
  ;
  return $error if $error;

  return "amount must be > 0" if $self->amount <= 0;
  
  return "Unknown invoice"
    unless my $cust_bill =
      qsearchs( 'cust_bill', { 'invnum' => $self->invnum } );

  return "Unknown payment"
    unless my $cust_pay = 
      qsearchs( 'cust_pay', { 'paynum' => $self->paynum } );

  $self->_date(time) unless $self->_date;

  return "Cannot apply more than remaining value of invoice"
    unless $self->amount <= $cust_bill->owed;

  return "Cannot apply more than remaining value of payment"
    unless $self->amount <= $cust_pay->unapplied;

  $self->SUPER::check;
}

=item cust_pay 

Returns the payment (see L<FS::cust_pay>)

=cut

sub cust_pay {
  my $self = shift;
  qsearchs( 'cust_pay', { 'paynum' => $self->paynum } );
}

=item cust_bill 

Returns the invoice (see L<FS::cust_bill>)

=cut

sub cust_bill {
  my $self = shift;
  qsearchs( 'cust_bill', { 'invnum' => $self->invnum } );
}

=back

=head1 BUGS

Delete and replace methods.

the checks for over-applied payments could be better done like the ones in
cust_bill_credit

=head1 SEE ALSO

L<FS::cust_pay>, L<FS::cust_bill>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

