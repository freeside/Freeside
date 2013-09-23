package FS::vend_pay;

use strict;
use base qw( FS::Record );
use FS::Record qw( dbh ); #qsearch qsearchs );
use FS::vend_bill_pay;

=head1 NAME

FS::vend_pay - Object methods for vend_pay records

=head1 SYNOPSIS

  use FS::vend_pay;

  $record = new FS::vend_pay \%hash;
  $record = new FS::vend_pay { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::vend_pay object represents a vendor payment.  FS::vend_pay inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item vendpaynum

primary key

=item vendnum

vendnum

=item _date

_date

=item paid

paid


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new payment.  To add the payment to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'vend_pay'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.
=cut

sub insert {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "inserting vend_pay: $error";
  }

  if ( $self->get('vendbillnum') ) {

    my $vend_bill_pay = new FS::vend_bill_pay {
      'vendpaynum'  => $self->vendpaynum,
      'vendbillnum' => $self->get('vendbillnum'),
      'amount'      => $self->paid,
    };

    $error = $vend_bill_pay->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "auto-inserting vend_bill_pay: $error";
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid payment.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('vendpaynum')
    || $self->ut_foreign_key('vendnum', 'vend_main', 'vendnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('paid')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

