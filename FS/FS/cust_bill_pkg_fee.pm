package FS::cust_bill_pkg_fee;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cust_bill_pkg_fee - Object methods for cust_bill_pkg_fee records

=head1 SYNOPSIS

  use FS::cust_bill_pkg_fee;

  $record = new FS::cust_bill_pkg_fee \%hash;
  $record = new FS::cust_bill_pkg_fee { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg_fee object records the origin of a fee.  
FS::cust_bill_pkg_fee inherits from FS::Record.  The following fields 
are currently supported:

=over 4

=item billpkgfeenum - primary key

=item billpkgnum - the billpkgnum of the fee line item

=item base_invnum - the invoice number (L<FS::cust_bill>) that caused 
(this portion of) the fee to be charged.

=item base_billpkgnum - the invoice line item (L<FS::cust_bill_pkg>) that
caused (this portion of) the fee to be charged.  May be null.

=item amount - the fee amount

=back

=head1 METHODS

=over 4

=cut

sub table { 'cust_bill_pkg_fee'; }

# seeing as these methods are not defined in this module I object to having
# perldoc noise for them

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('billpkgfeenum')
    || $self->ut_number('billpkgnum')
    || $self->ut_foreign_key('base_invnum', 'cust_bill', 'invnum')
    || $self->ut_foreign_keyn('base_billpkgnum', 'cust_bill_pkg', 'billpkgnum')
    || $self->ut_money('amount')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>

=cut

1;

