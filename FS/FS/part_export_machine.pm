package FS::part_export_machine;

use strict;
use base qw( FS::Record );
use FS::Record qw( dbh qsearch ); #qsearchs );
use FS::part_export;
use FS::svc_export_machine;

=head1 NAME

FS::part_export_machine - Object methods for part_export_machine records

=head1 SYNOPSIS

  use FS::part_export_machine;

  $record = new FS::part_export_machine \%hash;
  $record = new FS::part_export_machine { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_export_machine object represents an export hostname choice.
FS::part_export_machine inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item machinenum

primary key

=item exportnum

Export, see L<FS::part_export>

=item machine

Hostname or IP address

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'part_export_machine'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

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

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $svc_export_machine ( $self->svc_export_machine ) {
    my $error = $svc_export_machine->delete;
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
    $self->ut_numbern('machinenum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum')
    || $self->ut_domain('machine')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item svc_export_machine

=cut

sub svc_export_machine {
  my $self = shift;
  qsearch( 'svc_export_machine', { 'machinenum' => $self->machinenum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::part_export>, L<FS::Record>

=cut

1;

