package FS::cust_pay_void; 
use strict;
use vars qw( @ISA );
use Business::CreditCard;
use FS::UID qw(getotaker);
use FS::Record qw(qsearchs); # dbh qsearch );
#use FS::cust_bill;
#use FS::cust_bill_pay;
#use FS::cust_pay_refund;
#use FS::cust_main;

@ISA = qw( FS::Record );

=head1 NAME

FS::cust_pay_void - Object methods for cust_pay_void objects

=head1 SYNOPSIS

  use FS::cust_pay_void;

  $record = new FS::cust_pay_void \%hash;
  $record = new FS::cust_pay_void { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pay_void object represents a voided payment.  The following fields
are currently supported:

=over 4

=item paynum - primary key (assigned automatically for new payments)

=item custnum - customer (see L<FS::cust_main>)

=item paid - Amount of this payment

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item payby - `CARD' (credit cards), `CHEK' (electronic check/ACH),
`LECB' (phone bill billing), `BILL' (billing), or `COMP' (free)

=item payinfo - card number, check #, or comp issuer (4-8 lowercase alphanumerics; think username), respectively

=item paybatch - text field for tracking card processing

=item closed - books closed flag, empty or `Y'

=item void_date

=item reason

=back

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new payment.  To add the payment to the databse, see L<"insert">.

=cut

sub table { 'cust_pay_void'; }

=item insert

Adds this voided payment to the database.

=item delete

Currently unimplemented.

=cut

sub delete {
  return "Can't delete voided payments!";
}

=item replace OLD_RECORD

Currently unimplemented.

=cut

sub replace {
   return "Can't modify voided payments!";
}

=item check

Checks all fields to make sure this is a valid voided payment.  If there is an
error, returns the error, otherwise returns false.  Called by the insert
method.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('paynum')
    || $self->ut_numbern('custnum')
    || $self->ut_money('paid')
    || $self->ut_number('_date')
    || $self->ut_textn('paybatch')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->ut_numbern('void_date')
    || $self->ut_textn('reason')
  ;
  return $error if $error;

  return "paid must be > 0 " if $self->paid <= 0;

  return "unknown cust_main.custnum: ". $self->custnum
    unless $self->invnum
           || qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->void_date(time) unless $self->void_date;

  $self->payby =~ /^(CARD|CHEK|LECB|BILL|COMP)$/ or return "Illegal payby";
  $self->payby($1);

  #false laziness with cust_refund::check
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

  $self->otaker(getotaker);

  $self->SUPER::check;
}

=item cust_main

Returns the parent customer object (see L<FS::cust_main>).

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
}

=item payinfo_masked

Returns a "masked" payinfo field with all but the last four characters replaced
by 'x'es.  Useful for displaying credit cards.

=cut

sub payinfo_masked {
  my $self = shift;
  my $payinfo = $self->payinfo;
  'x'x(length($payinfo)-4). substr($payinfo,(length($payinfo)-4));
}

=back

=head1 BUGS

Delete and replace methods.

=head1 SEE ALSO

L<FS::cust_pay>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

