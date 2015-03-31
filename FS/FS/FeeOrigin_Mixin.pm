package FS::FeeOrigin_Mixin;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::part_fee;
use FS::cust_bill_pkg;

# is there a nicer idiom for this?
our @subclasses = qw( FS::cust_event_fee FS::cust_pkg_reason_fee );
use FS::cust_event_fee;
use FS::cust_pkg_reason_fee;

=head1 NAME

FS::FeeOrigin_Mixin - Common interface for fee origin records

=head1 SYNOPSIS

  use FS::cust_event_fee;

  $record = new FS::cust_event_fee \%hash;
  $record = new FS::cust_event_fee { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::FeeOrigin_Mixin object associates the timestamped event that triggered 
a fee (which may be a billing event, or something else like a package
suspension) to the resulting invoice line item (L<FS::cust_bill_pkg> object).
The following fields are required:

=over 4

=item billpkgnum - key of the cust_bill_pkg record representing the fee 
on an invoice.  This is a unique column but can be NULL to indicate a fee that
hasn't been billed yet.  In that case it will be billed the next time billing
runs for the customer.

=item feepart - key of the fee definition (L<FS::part_fee>).

=item nextbill - 'Y' if the fee should be charged on the customer's next bill,
rather than causing a bill to be produced immediately.

=back

=head1 CLASS METHODS

=over 4

=item by_cust CUSTNUM[, PARAMS]

Finds all cust_event_fee records belonging to the customer CUSTNUM.

PARAMS can be additional params to pass to qsearch; this really only works
for 'hashref' and 'order_by'.

=cut

# invoke for all subclasses, and return the results as a flat list

sub by_cust {
  my $class = shift;
  my @args = @_;
  return map { $_->_by_cust(@args) } @subclasses;
}

=back

=head1 INTERFACE

=over 4

=item _by_cust CUSTNUM[, PARAMS]

The L</by_cust> search method. Each subclass must implement this.

=item cust_bill

If the fee origin generates a fee based on past invoices (for example, an
invoice event that charges late fees), this method should return the
L<FS::cust_bill> object that will be the basis for the fee. If this returns
nothing, then then fee will be based on the rest of the invoice where it
appears.

=item cust_pkg

If the fee origin generates a fee limited in scope to one package (for
example, a package reconnection fee event), this method should return the
L<FS::cust_pkg> object the fee applies to. If it's a percentage fee, this
determines which charges it's a percentage of; otherwise it just affects the
fee description appearing on the invoice.

Currently not tested in combination with L</cust_bill>; be careful.

=cut

# stubs

sub _by_cust { my $class = shift; die "'$class' must provide _by_cust method" }

sub cust_bill { '' }

sub cust_pkg { '' }

# still necessary in 4.x; can't FK the billpkgnum because of voids
sub cust_bill_pkg {
  my $self = shift;
  $self->billpkgnum ? FS::cust_bill_pkg->by_key($self->billpkgnum) : '';
}

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_event_fee>, L<FS::cust_pkg_reason_fee>, L<FS::cust_bill_pkg>, 
L<FS::part_fee>

=cut

1;

