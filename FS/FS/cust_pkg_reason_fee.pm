package FS::cust_pkg_reason_fee;

use strict;
use base qw( FS::Record FS::FeeOrigin_Mixin );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cust_pkg_reason_fee - Object methods for cust_pkg_reason_fee records

=head1 SYNOPSIS

  use FS::cust_pkg_reason_fee;

  $record = new FS::cust_pkg_reason_fee \%hash;
  $record = new FS::cust_pkg_reason_fee { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pkg_reason_fee object links a package status change that charged
a fee (an L<FS::cust_pkg_reason> object) to the resulting invoice line item.
FS::cust_pkg_reason_fee inherits from FS::Record and FS::FeeOrigin_Mixin.  
The following fields are currently supported:

=over 4

=item pkgreasonfeenum - primary key

=item pkgreasonnum - key of the cust_pkg_reason object that triggered the fee.

=item billpkgnum - key of the cust_bill_pkg record representing the fee on an
invoice. This can be NULL if the fee is scheduled but hasn't been billed yet.

=item feepart - key of the fee definition (L<FS::part_fee>).

=item nextbill - 'Y' if the fee should be charged on the customer's next bill,
rather than causing a bill to be produced immediately.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'cust_pkg_reason_fee'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('pkgreasonfeenum')
    || $self->ut_foreign_key('pkgreasonnum', 'cust_pkg_reason', 'num')
    || $self->ut_foreign_keyn('billpkgnum', 'cust_bill_pkg', 'billpkgnum')
    || $self->ut_foreign_key('feepart', 'part_fee', 'feepart')
    || $self->ut_flag('nextbill')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 CLASS METHODS

=over 4

=item _by_cust CUSTNUM[, PARAMS]

See L<FS::FeeOrigin_Mixin/by_cust>.

=cut

sub _by_cust {
  my $class = shift;
  my $custnum = shift or return;
  my %params = @_;
  $custnum =~ /^\d+$/ or die "bad custnum $custnum";
    
  my $where = ($params{hashref} && keys (%{ $params{hashref} }))
              ? 'AND'
              : 'WHERE';
  qsearch({
    table     => 'cust_pkg_reason_fee',
    addl_from => 'JOIN cust_pkg_reason ON (cust_pkg_reason_fee.pkgreasonnum = cust_pkg_reason.num) ' .
                 'JOIN cust_pkg USING (pkgnum) ',
    extra_sql => "$where cust_pkg.custnum = $custnum",
    %params
  });
}

=back

=head1 METHODS

=over 4

=item cust_pkg

Returns the package that triggered the fee.

=cut

sub cust_pkg {
  my $self = shift;
  $self->cust_pkg_reason->cust_pkg;
}

=head1 SEE ALSO

L<FS::FeeOrigin_Mixin>, L<FS::cust_pkg_reason>, L<part_fee>

=cut

1;

