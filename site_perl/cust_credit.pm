package FS::cust_credit;

use strict;
use vars qw( @ISA );
use FS::UID qw( getotaker );
use FS::Record qw( qsearchs );
use FS::cust_main;

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

An FS::cust_credit object represents a credit.  FS::cust_credit inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item crednum - primary key (assigned automatically for new credits)

=item custnum - customer (see L<FS::cust_main>)

=item amount - amount of the credit

=item credited - how much of this credit that is still outstanding, which is
amount minus all refunds (see L<FS::cust_refund>).

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

When adding new invoices, credited must be amount (or null, in which case it is
automatically set to amount).

=cut

sub insert {
  my $self = shift;

  $self->credited($self->amount) if $self->credited eq '';
  return "credited != amount!"
    unless $self->credited == $self->amount;

  $self->SUPER::insert;
}

=item delete

Currently unimplemented.

=cut

sub delete {
  return "Can't remove credit!"
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Only credited may be changed.  Credited is normally updated by creating and
inserting a refund (see L<FS::cust_refund>).

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );

  return "Can't change custnum!" unless $old->custnum eq $new->custnum;
  return "Can't change date!" unless $old->_date eq $new->_date;
  return "Can't change amount!" unless $old->amount eq $new->amount;
  return "(New) credited can't be > (new) amount!"
    if $new->credited > $new->amount;

  $new->SUPER::replace($old);
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
    || $self->ut_money('credited')
    || $self->ut_textn('reason');
  ;
  return $error if $error;

  return "Unknown customer"
    unless qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->_date(time) unless $self->_date;

  $self->otaker(getotaker);

  ''; #no error
}

=back

=head1 VERSION

$Id: cust_credit.pm,v 1.2 1998-12-29 11:59:38 ivan Exp $

=head1 BUGS

The delete method.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_refund>, L<FS::cust_bill>, schema.html from the base
documentation.

=head1 HISTORY

ivan@sisd.com 98-mar-17

pod, otaker from FS::UID ivan@sisd.com 98-sep-21

$Log: cust_credit.pm,v $
Revision 1.2  1998-12-29 11:59:38  ivan
mostly properly OO, some work still to be done with svc_ stuff


=cut

1;

