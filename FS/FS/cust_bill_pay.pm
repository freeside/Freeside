package FS::cust_bill_pay;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_bill;
use FS::cust_pay;

@ISA = qw( FS::Record );

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

=cut

sub insert {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->check;
  return $error if $error;

  $error = $self->SUPER::insert;

  my $cust_pay = qsearchs('cust_pay', { 'paynum' => $self->paynum } ) or do {
    $dbh->rollback if $oldAutoCommit;
    return "unknown cust_pay.paynum: ". $self->paynum;
  };

  my $pay_total = 0;
  $pay_total += $_ foreach map { $_->amount }
    qsearch('cust_bill_pay', { 'paynum' => $self->paynum } );

  if ( sprintf("%.2f", $pay_total) > sprintf("%.2f", $cust_pay->paid) ) {
    $dbh->rollback if $oldAutoCommit;
    return "total cust_bill_pay.amount $pay_total for paynum ". $self->paynum.
           " greater than cust_pay.paid ". $cust_pay->paid;
  }

  my $cust_bill = qsearchs('cust_bill', { 'invnum' => $self->invnum } ) or do {
    $dbh->rollback if $oldAutoCommit;
    return "unknown cust_bill.invnum: ". $self->invnum;
  };

  my $bill_total = 0;
  $bill_total += $_ foreach map { $_->amount }
    qsearch('cust_bill_pay', { 'invnum' => $self->invnum } );
  $bill_total += $_ foreach map { $_->amount } 
    qsearch('cust_credit_bill', { 'invnum' => $self->invnum } );
  if ( sprintf("%.2f", $bill_total) > sprintf("%.2f", $cust_bill->charged) ) {
    $dbh->rollback if $oldAutoCommit;
    return "total cust_bill_pay.amount and cust_credit_bill.amount $bill_total".
           " for invnum ". $self->invnum.
           " greater than cust_bill.charged ". $cust_bill->charged;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

=item delete

Currently unimplemented (accounting reasons).

=cut

sub delete {
  return "Can't (yet?) delete cust_bill_pay records!";
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

  return "amount must be > 0" if $self->amount == 0;

  $self->_date(time) unless $self->_date;

  ''; #no error
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

=head1 VERSION

$Id: cust_bill_pay.pm,v 1.10 2001-12-21 20:55:35 ivan Exp $

=head1 BUGS

Delete and replace methods.

the checks for over-applied payments could be better done like the ones in
cust_bill_credit

=head1 SEE ALSO

L<FS::cust_pay>, L<FS::cust_bill>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

