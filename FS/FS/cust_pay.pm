package FS::cust_pay;

use strict;
use vars qw( @ISA );
use Business::CreditCard;
use FS::Record qw( qsearchs );
use FS::cust_bill;

@ISA = qw( FS::Record );

=head1 NAME

FS::cust_pay - Object methods for cust_pay objects

=head1 SYNOPSIS

  use FS::cust_pay;

  $record = new FS::cust_pay \%hash;
  $record = new FS::cust_pay { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pay object represents a payment.  FS::cust_pay inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item paynum - primary key (assigned automatically for new payments)

=item invnum - Invoice (see L<FS::cust_bill>)

=item paid - Amount of this payment

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item payby - `CARD' (credit cards), `BILL' (billing), or `COMP' (free)

=item payinfo - card number, P.O.#, or comp issuer (4-8 lowercase alphanumerics; think username)

=item paybatch - text field for tracking card processing

=back

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new payment.  To add the payment to the databse, see L<"insert">.

=cut

sub table { 'cust_pay'; }

=item insert

Adds this payment to the databse, and updates the invoice (see
L<FS::cust_bill>).

=cut

sub insert {
  my $self = shift;

  my $error;

  $error = $self->check;
  return $error if $error;

  my $old_cust_bill = qsearchs( 'cust_bill', { 'invnum' => $self->invnum } );
  return "Unknown invnum" unless $old_cust_bill;
  my %hash = $old_cust_bill->hash;
  $hash{'owed'} = sprintf("%.2f", $hash{owed} - $self->paid );
  my $new_cust_bill = new FS::cust_bill ( \%hash );

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  $error = $new_cust_bill->replace($old_cust_bill);
  return "Error modifying cust_bill: $error" if $error;

  $self->SUPER::insert;
}

=item delete

Currently unimplemented (accounting reasons).

=cut

sub delete {
  return "Can't (yet?) delete cust_pay records!";
}

=item replace OLD_RECORD

Currently unimplemented (accounting reasons).

=cut

sub replace {
   return "Can't (yet?) modify cust_pay records!";
}

=item check

Checks all fields to make sure this is a valid payment.  If there is an error,
returns the error, otherwise returns false.  Called by the insert method.

=cut

sub check {
  my $self = shift;

  my $error;

  $error =
    $self->ut_numbern('paynum')
    || $self->ut_number('invnum')
    || $self->ut_money('paid')
    || $self->ut_numbern('_date')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  $self->payby =~ /^(CARD|BILL|COMP)$/ or return "Illegal payby";
  $self->payby($1);

  if ( $self->payby eq 'CARD' ) {
    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $self->payinfo($payinfo);
    if ( $self->payinfo ) {
      $self->payinfo =~ /^(\d{13,16})$/
        or return "Illegal (mistyped?) credit card number (payinfo)";
      $self->payinfo($1);
      validate($self->payinfo) or return "Illegal credit card number";
      return "Unknown card type" if cardtype($self->payinfo) eq "Unknown";
    } else {
      $self->payinfo('N/A');
    }

  } else {
    $error = $self->ut_textn('payinfo');
    return $error if $error;
  }

  $error = $self->ut_textn('paybatch');
  return $error if $error;

  ''; #no error

}

=back

=head1 VERSION

$Id: cust_pay.pm,v 1.1 1999-08-04 09:03:53 ivan Exp $

=head1 BUGS

Delete and replace methods.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_bill>, schema.html from the base documentation.

=cut

1;

