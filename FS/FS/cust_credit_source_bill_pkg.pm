package FS::cust_credit_source_bill_pkg;
use base qw( FS::cust_main_Mixin FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cust_credit_source_bill_pkg - Object methods for cust_credit_source_bill_pkg records

=head1 SYNOPSIS

  use FS::cust_credit_source_bill_pkg;

  $record = new FS::cust_credit_source_bill_pkg \%hash;
  $record = new FS::cust_credit_source_bill_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_credit_source_bill_pkg object represents the record that a credit
was triggered by a specific line item.  FS::cust_credit_source_bill_pkg
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item creditsourcebillpkgnum

Primary key

=item crednum

Credit (see L<FS::cust_credit>)

=item billpkgnum

Line item (see L<FS::cust_bill_pkg>)

=item amount

Amount specific to this line item.

=item currency

Currency

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_credit_source_bill_pkg'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

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
    $self->ut_numbern('creditsourcebillpkgnum')
    || $self->ut_foreign_key('crednum', 'cust_credit', 'crednum')
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg', 'billpkgnum')
    || $self->ut_money('amount')
    || $self->ut_currencyn('currency')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

Terminology/documentation surrounding credit "sources" vs. credit
"applications" is hard to understand.

=head1 SEE ALSO

L<FS::cust_credit>, L<FS::cust_bill_pkg>, L<FS::Record>

=cut

1;

