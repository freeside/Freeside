package FS::cust_refund;

use strict;
use vars qw( @ISA );
use Business::CreditCard;
use FS::Record qw( qsearchs );
use FS::UID qw(getotaker);
use FS::cust_credit;

@ISA = qw( FS::Record );

=head1 NAME

FS::cust_refund - Object method for cust_refund objects

=head1 SYNOPSIS

  use FS::cust_refund;

  $record = new FS::cust_refund \%hash;
  $record = new FS::cust_refund { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_refund represents a refund.  FS::cust_refund inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item refundnum - primary key (assigned automatically for new refunds)

=item crednum - Credit (see L<FS::cust_credit>)

=item refund - Amount of the refund

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item payby - `CARD' (credit cards), `BILL' (billing), or `COMP' (free)

=item payinfo - card number, P.O.#, or comp issuer (4-8 lowercase alphanumerics; think username)

=item otaker - order taker (assigned automatically, see L<FS::UID>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new refund.  To add the refund to the database, see L<"insert">.

=cut

sub table { 'cust_refund'; }

=item insert

Adds this refund to the database, and updates the credit (see
L<FS::cust_credit>).

=cut

sub insert {
  my $self = shift;

  my $error;

  $error=$self->check;
  return $error if $error;

  my $old_cust_credit =
    qsearchs( 'cust_credit', { 'crednum' => $self->crednum } );
  return "Unknown crednum" unless $old_cust_credit;
  my %hash = $old_cust_credit->hash;
  $hash{credited} = sprintf("%.2f", $hash{credited} - $self->refund );
  my($new_cust_credit) = new FS::cust_credit ( \%hash );

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  $error = $new_cust_credit->replace($old_cust_credit);
  return "Error modifying cust_credit: $error" if $error;

  $self->SUPER::insert;
}

=item delete

Currently unimplemented (accounting reasons).

=cut

sub delete {
  return "Can't (yet?) delete cust_refund records!";
}

=item replace OLD_RECORD

Currently unimplemented (accounting reasons).

=cut

sub replace {
   return "Can't (yet?) modify cust_refund records!";
}

=item check

Checks all fields to make sure this is a valid refund.  If there is an error,
returns the error, otherwise returns false.  Called by the insert method.

=cut

sub check {
  my $self = shift;

  my $error;

  $error =
    $self->ut_number('refundnum')
    || $self->ut_number('crednum')
    || $self->ut_money('amount')
    || $self->ut_numbern('_date')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  $self->payby =~ /^(CARD|BILL|COMP)$/ or return "Illegal payby";
  $self->payby($1);

  if ( $self->payby eq 'CARD' ) {
    my $payinfo = $self->payinfo;
    $self->payinfo($payinfo =~ s/\D//g);
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

  $self->otaker(getotaker);

  ''; #no error
}

=back

=head1 VERSION

$Id: cust_refund.pm,v 1.1 1999-08-04 09:03:53 ivan Exp $

=head1 BUGS

Delete and replace methods.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_credit>, schema.html from the base documentation.

=cut

1;

