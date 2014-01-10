package FS::cust_pkg_usageprice;
use base qw( FS::Record );

use strict;
use FS::Record qw( dbh ); # qsearch qsearchs );

=head1 NAME

FS::cust_pkg_usageprice - Object methods for cust_pkg_usageprice records

=head1 SYNOPSIS

  use FS::cust_pkg_usageprice;

  $record = new FS::cust_pkg_usageprice \%hash;
  $record = new FS::cust_pkg_usageprice { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pkg_usageprice object represents an specific customer package usage
pricing add-on.  FS::cust_pkg_usageprice inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item usagepricenum

primary key

=item pkgnum

pkgnum

=item usagepricepart

usagepricepart

=item quantity

quantity


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_pkg_usageprice'; }

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
    $self->ut_numbern('usagepricenum')
    || $self->ut_number('pkgnum')
    || $self->ut_number('usagepricepart')
    || $self->ut_number('quantity')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item price

Returns the price for this customer usage pricing add-on (quantity of this
record multiplied by price of the associated FS::part_pkg_usageprice record)

=cut

sub price {
  my $self = shift;
  sprintf('%.2f', $self->quantity * $self->part_pkg_usageprice->price);
}

=item apply

Applies this customer usage pricing add-on.  (Mulitplies quantity of this record
by part_pkg_usageprice.amount, and applies to to any services of this package
matching part_pkg_usageprice.target)

If there is an error, returns the error, otherwise returns false.

=cut

sub apply {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = '';

  my $part_pkg_usageprice = $self->part_pkg_usageprice;

  my $amount = $self->quantity * $part_pkg_usageprice->amount;

  my $target = $part_pkg_usageprice->target;

  #these are ongoing counters that count down, so increment them
  if ( $target =~ /^svc_acct.(\w+)$/ ) {

    my $method = "increment_$1";

    foreach my $cust_svc ( $self->cust_pkg->cust_svc(svcdb=>'svc_acct') ) {
      $error ||= $cust_svc->svc_x->$method( $amount );
    }

  #this is a maximum number, not a counter, so we want to take our number
  # and add it to the default for the service
  } elsif ( $target eq 'svc_conferencing.participants' ) {

    foreach my $cust_svc ($self->cust_pkg->cust_svc(svcdb=>'svc_conferencing')){
      my $svc_conferencing = $cust_svc->svc_x;
      my $base_amount = $cust_svc->part_svc->part_svc_column('participants')->columnvalue || 0; #assuming.. D?  F would get overridden  :/
      $svc_conferencing->participants( $base_amount + $amount );
      $error ||= $svc_conferencing->replace;
    }

  #this has no multiplication involved, its just a set only
  #} elsif ( $target eq 'svc_conferencing.confqualitynum' ) {

  }

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
  } else {
    $dbh->commit if $oldAutoCommit;
  }
  return $error;

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::part_pkg_usageprice>, L<FS::cust_pkg>, L<FS::Record>

=cut

1;

