package FS::cust_credit;

use strict;
use vars qw( @ISA );
use FS::UID qw( getotaker );
use FS::Record qw( qsearchs );
use FS::cust_main;
use FS::cust_refund;

@ISA = qw( FS::Record );

=head1 NAME

FS::cust_credit - Object methods for cust_credit records

=head1 SYNOPSIS

  use FS::cust_credit;

  $record = new FS::cust_credit \%hash;
  $record = new FS::cust_credit { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_credit object represents a credit; the equivalent of a negative
B<cust_bill> record (see L<FS::cust_bill>).  FS::cust_credit inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item crednum - primary key (assigned automatically for new credits)

=item custnum - customer (see L<FS::cust_main>)

=item amount - amount of the credit

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item otaker - order taker (assigned automatically, see L<FS::UID>)

=item reason - text

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new credit.  To add the credit to the database, see L<"insert">.

=cut

sub table { 'cust_credit'; }

=item insert

Adds this credit to the database ("Posts" the credit).  If there is an error,
returns the error, otherwise returns false.

=item delete

Currently unimplemented.

=cut

sub delete {
  return "Can't remove credit!"
}

=item replace OLD_RECORD

Credits may not be modified; there would then be no record the credit was ever
posted.

=cut

sub replace {
  return "Can't modify credit!"
}

=item check

Checks all fields to make sure this is a valid credit.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('crednum')
    || $self->ut_number('custnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('amount')
    || $self->ut_textn('reason');
  ;
  return $error if $error;

  return "Unknown customer"
    unless qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->_date(time) unless $self->_date;

  $self->otaker(getotaker);

  ''; #no error
}

=item cust_refund

Returns all refunds (see L<FS::cust_refund>) for this credit.

=cut

sub cust_refund {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_refund', { 'crednum' => $self->crednum } )
  ;
}

=item credited

Returns the amount of this credit that is still outstanding; which is
amount minus all refunds (see L<FS::cust_refund>).

=cut

sub credited {
  my $self = shift;
  my $amount = $self->amount;
  $amount -= $_->refund foreach ( $self->cust_refund );
  $amount;
}

=back

=head1 VERSION

$Id: cust_credit.pm,v 1.3 2001-04-09 23:05:15 ivan Exp $

=head1 BUGS

The delete method.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_refund>, L<FS::cust_bill>, schema.html from the base
documentation.

=cut

1;

