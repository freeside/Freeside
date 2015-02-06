package FS::pkg_discount_Mixin;

use strict;
use NEXT;
use FS::Record qw(dbh);

=head1 NAME

FS::pkg_discount_Mixin - mixin class for package-discount link objects.

=head1 DESCRIPTION

Implements some behavior that's common to cust_pkg_discount and 
quotation_pkg_discount objects. The only required field is "discountnum",
a foreign key to L<FS::discount>.

=head1 METHODS

=over 4

=item insert

Inserts the record. If the 'discountnum' field is -1, this will first create
a discount using the contents of the '_type', 'amount', 'percent', 'months',
and 'setup' field. The new discount will be disabled, since it's a one-off
discount.

=cut

sub insert {
  my $self = shift;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  
  if ( $self->discountnum == -1 ) {
    my $discount = new FS::discount {
      '_type'    => $self->_type,
      'amount'   => $self->amount,
      'percent'  => $self->percent,
      'months'   => $self->months,
      'setup'    => $self->setup,
      #'linked'   => $self->linked,
      'disabled' => 'Y',
    };
    my $error = $discount->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error; 
    } 
    $self->set('discountnum', $discount->discountnum);
  }

  my $error = $self->NEXT::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
  
} 

=back

=cut

1;
