package FS::cust_credit_bill;

use strict;
use vars qw( @ISA $conf );
use FS::UID qw( getotaker );
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
#use FS::cust_refund;
use FS::cust_credit;
use FS::cust_bill;

@ISA = qw( FS::Record );

#ask FS::UID to run this stuff for us later
FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
} );

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
L<FS::cust_credit>) to an invoice (see L<FS::cust_bill>).  FS::cust_credit
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item creditbillnum - primary key

=item crednum - credit being applied 

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

=cut

sub insert {
  my $self = shift;
  my $error = $self->SUPER::insert(@_);
  return $error if $error;

  if ( $conf->exists('invoice_send_receipts') ) {
    my $send_error = $self->cust_bill->send;
    warn "Error sending receipt: $send_error\n" if $send_error;
  }

  '';
}

=item delete

Currently unimplemented.

=cut

sub delete {
  my $self = shift;
  return "Can't delete application for closed credit"
    if $self->cust_credit->closed =~ /^Y/i;
  $self->SUPER::delete(@_);
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
    $self->ut_numbern('creditbillnum')
    || $self->ut_number('crednum')
    || $self->ut_number('invnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('amount')
  ;
  return $error if $error;

  return "amount must be > 0" if $self->amount <= 0;

  return "Unknown credit"
    unless my $cust_credit = 
      qsearchs( 'cust_credit', { 'crednum' => $self->crednum } );

  return "Unknown invoice"
    unless my $cust_bill =
      qsearchs( 'cust_bill', { 'invnum' => $self->invnum } );

  $self->_date(time) unless $self->_date;

  return "Cannot apply more than remaining value of credit"
    unless $self->amount <= $cust_credit->credited;

  return "Cannot apply more than remaining value of invoice"
    unless $self->amount <= $cust_bill->owed;

  $self->SUPER::check;
}

=item sub cust_credit

Returns the credit (see L<FS::cust_credit>)

=cut

sub cust_credit {
  my $self = shift;
  qsearchs( 'cust_credit', { 'crednum' => $self->crednum } );
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

The delete method.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_refund>, L<FS::cust_bill>, L<FS::cust_credit>,
schema.html from the base documentation.

=cut

1;

