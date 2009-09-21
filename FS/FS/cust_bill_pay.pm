package FS::cust_bill_pay;

use strict;
use vars qw( @ISA $conf );
use FS::Record qw( qsearchs );
use FS::cust_main_Mixin;
use FS::cust_bill_ApplicationCommon;
use FS::cust_bill;
use FS::cust_pay;
use FS::cust_pkg;

@ISA = qw( FS::cust_main_Mixin FS::cust_bill_ApplicationCommon );

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
specific invoice.  FS::cust_bill_pay inherits from
FS::cust_bill_ApplicationCommon and FS::Record.  The following fields are
currently supported:

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

sub _app_source_name   { 'payment'; }
sub _app_source_table { 'cust_pay'; }
sub _app_lineitem_breakdown_table { 'cust_bill_pay_pkg'; }
sub _app_part_pkg_weight_column { 'pay_weight'; }

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
  return "Can't delete application for closed invoice"
    if $self->cust_bill->closed =~ /^Y/i;
  $self->SUPER::delete(@_);
}

=item replace OLD_RECORD

Currently unimplemented (accounting reasons).

=cut

sub replace {
   return "Can't modify application of payment!";
}

=item check

Checks all fields to make sure this is a valid payment application.  If there
is an error, returns the error, otherwise returns false.  Called by the insert
method.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('billpaynum')
    || $self->ut_foreign_key('paynum', 'cust_pay', 'paynum' )
    || $self->ut_foreign_key('invnum', 'cust_bill', 'invnum' )
    || $self->ut_numbern('_date')
    || $self->ut_money('amount')
    || $self->ut_foreign_keyn('pkgnum', 'cust_pkg', 'pkgnum')
  ;
  return $error if $error;

  return "amount must be > 0" if $self->amount <= 0;
  
  $self->_date(time) unless $self->_date;

  return "Cannot apply more than remaining value of invoice"
    unless $self->amount <= $self->cust_bill->owed;

  return "Cannot apply more than remaining value of payment"
    unless $self->amount <= $self->cust_pay->unapplied;

  $self->SUPER::check;
}

=item cust_pay 

Returns the payment (see L<FS::cust_pay>)

=cut

sub cust_pay {
  my $self = shift;
  qsearchs( 'cust_pay', { 'paynum' => $self->paynum } );
}

=item send_receipt HASHREF | OPTION => VALUE ...


Sends a payment receipt for the associated payment, against this specific
invoice.  If there is an error, returns the error, otherwise returns false.

See L<FS::cust_pay/send_receipt>.

=cut

sub send_receipt {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };
  $self->cust_pay->send_receipt(
    'cust_bill' => $self->cust_bill,
    %$opt,
  );
}

=back

=head1 BUGS

Delete and replace methods.

=head1 SEE ALSO

L<FS::cust_pay>, L<FS::cust_bill>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

