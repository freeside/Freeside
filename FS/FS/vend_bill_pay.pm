package FS::vend_bill_pay;
use base qw( FS::Record );

use strict;
use FS::Record qw( dbh ); #qsearch #qsearchs );

=head1 NAME

FS::vend_bill_pay - Object methods for vend_bill_pay records

=head1 SYNOPSIS

  use FS::vend_bill_pay;

  $record = new FS::vend_bill_pay \%hash;
  $record = new FS::vend_bill_pay { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::vend_bill_pay object represents the application of a vendor payment to a
specific invoice or payment. FS::vend_bill_pay inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item vendbillpaynum

primary key

=item vendbillnum

vendbillnum

=item vendpaynum

vendpaynum

=item amount

amount


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'vend_bill_pay'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  #magically auto-deleting for the simple case
  foreach my $vend_pay ( $self->vend_pay ) {
    my $error = $vend_pay->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}


=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('vendbillpaynum')
    || $self->ut_foreign_key('vendbillnum', 'vend_bill', 'vendbillnum')
    || $self->ut_foreign_key('vendpaynum', 'vend_pay', 'vendpaynum')
    || $self->ut_money('amount')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item vend_pay

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

