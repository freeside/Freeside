package FS::cust_pkg_discount;

use strict;
use base qw( FS::otaker_Mixin FS::cust_main_Mixin FS::Record );
use FS::Record qw( dbh qsearchs ); # qsearch );
use FS::cust_pkg;
use FS::discount;

=head1 NAME

FS::cust_pkg_discount - Object methods for cust_pkg_discount records

=head1 SYNOPSIS

  use FS::cust_pkg_discount;

  $record = new FS::cust_pkg_discount \%hash;
  $record = new FS::cust_pkg_discount { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pkg_discount object represents the application of a discount to a
customer package.  FS::cust_pkg_discount inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item pkgdiscountnum

primary key

=item pkgnum

Customer package (see L<FS::cust_pkg>)

=item discountnum

Discount (see L<FS::discount>)

=item months_used

months_used

=item end_date

end_date

=item usernum

order taker, see L<FS::access_user>


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new discount application.  To add the record to the database, see
 L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_pkg_discount'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  #my( $self, %options ) = @_;
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( $self->discountnum == -1 ) {
    my $discount = new FS::discount {
      '_type'    => $self->_type,
      'amount'   => $self->amount,
      'percent'  => $self->percent,
      'months'   => $self->months,
      'setup'   => $self->setup,
      'disabled' => 'Y',
    };
    my $error = $discount->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    $self->discountnum($discount->discountnum);
  }

  my $error = $self->SUPER::insert; #(@_); #(%options);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid discount applciation.  If there
is an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('pkgdiscountnum')
    || $self->ut_foreign_key('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_foreign_key('discountnum', 'discount', 'discountnum' )
    || $self->ut_float('months_used') #actually decimal, but this will do
    || $self->ut_numbern('end_date')
    || $self->ut_alphan('otaker')
    || $self->ut_numbern('usernum')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
  ;
  return $error if $error;

  return "Discount does not apply to setup fees, and package has no recurring"
    if ! $self->discount->setup && $self->cust_pkg->part_pkg->freq =~ /^0/;

  $self->usernum($FS::CurrentUser::CurrentUser->usernum) unless $self->usernum;

  $self->SUPER::check;
}

=item cust_pkg

Returns the customer package (see L<FS::cust_pkg>).

=cut

sub cust_pkg {
  my $self = shift;
  qsearchs('cust_pkg', { 'pkgnum' => $self->pkgnum } );
}

=item discount

Returns the discount (see L<FS::discount>).

=cut

sub discount {
  my $self = shift;
  qsearchs('discount', { 'discountnum' => $self->discountnum } );
}

=item increment_months_used

Increments months_used by the given parameter

=cut

sub increment_months_used {
  my( $self, $used ) = @_;
  #UPDATE cust_pkg_discount SET months_used = months_used + ?
  #leaves no history, and billing is mutexed per-customer, so the dum way is ok
  $self->months_used( $self->months_used + $used );
  $self->replace();
}

=item status

=cut

sub status {
  my $self = shift;
  my $discount = $self->discount;

  if ( $self->disabled ne 'Y' 
       and ( ! $discount->months || $self->months_used < $discount->months )
             #XXX also end date
     ) {
    'active';
  } else {
    'expired';
  }
}

# Used by FS::Upgrade to migrate to a new database.
sub _upgrade_data {  # class method
  my ($class, %opts) = @_;
  $class->_upgrade_otaker(%opts);
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::discount>, L<FS::cust_pkg>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

