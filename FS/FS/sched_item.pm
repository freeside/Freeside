package FS::sched_item;
use base qw( FS::Record );

use strict;
use FS::Record qw( dbh ); # qsearch qsearchs );
use FS::sched_avail;

=head1 NAME

FS::sched_item - Object methods for sched_item records

=head1 SYNOPSIS

  use FS::sched_item;

  $record = new FS::sched_item \%hash;
  $record = new FS::sched_item { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::sched_item object represents an schedulable item, such as an installer,
meeting room or truck.  FS::sched_item inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item itemnum

primary key

=item usernum

usernum

=item disabled

disabled


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new item.  To add the item to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'sched_item'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid item.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('itemnum')
    || $self->ut_foreign_keyn('usernum', 'access_user', 'usernum')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item name

Returns a name for this item; either the name of the associated employee (see
L<FS::access_user>), or the itemname field.

=cut

sub name {
  my $self = shift;
  my $access_user = $self->access_user;
  $access_user ? $access_user->name : $self->itemname;
}

=item replace_sched_avail SCHED_AVAIL, ...

Replaces the existing availability schedule with the list of passed-in
FS::sched_avail objects

=cut

sub replace_sched_avail {
  my( $self, @new_sched_avail ) = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $old_sched_avail ( $self->sched_avail ) {
    my $error = $old_sched_avail->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $new_sched_avail ( @new_sched_avail ) {
    $new_sched_avail->itemnum( $self->itemnum );
    my $error = $new_sched_avail->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::access_user>, L<FS::sched_avail>, L<FS::Record>

=cut

1;

