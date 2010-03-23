package FS::mailinglist;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch dbh ); # qsearchs );
use FS::mailinglistmember;

=head1 NAME

FS::mailinglist - Object methods for mailinglist records

=head1 SYNOPSIS

  use FS::mailinglist;

  $record = new FS::mailinglist \%hash;
  $record = new FS::mailinglist { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::mailinglist object represents a mailing list  FS::mailinglist inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item listnum

primary key

=item listname

Mailing list name

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new mailing list.  To add the mailing list to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'mailinglist'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

sub delete {
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

  foreach my $member ( $self->mailinglistmember ) {
    my $error = $member->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid mailing list.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('listnum')
    || $self->ut_text('listname')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item mailinglistmember

=cut

sub mailinglistmember {
  my $self = shift;
  qsearch('mailinglistmember', { 'listnum' => $self->listnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::mailinglistmember>, L<FS::svc_mailinglist>, L<FS::Record>, schema.html
from the base documentation.

=cut

1;

