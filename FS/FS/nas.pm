package FS::nas;

use strict;
use base qw( FS::m2m_Common FS::Record );
use FS::Record qw( qsearch qsearchs dbh );
use FS::export_nas;
use FS::part_export;

=head1 NAME

FS::nas - Object methods for nas records

=head1 SYNOPSIS

  use FS::nas;

  $record = new FS::nas \%hash;
  $record = new FS::nas { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::nas object represents a RADIUS client.  FS::nas inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item nasnum - primary key

=item nasname - "NAS name", i.e. IP address

=item shortname - short descriptive name

=item type - the equipment vendor

=item ports

=item secret - the authentication secret for this client

=item server - virtual server name (optional)

=item community

=item description - a longer descriptive name


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new NAS.  To add the NAS to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'nas'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database and remove all linked exports.

=cut

sub delete {
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $self = shift;
  my $error = $self->process_m2m(
    link_table    => 'export_nas',
    target_table  => 'part_export',
    params        => []
  ) || $self->SUPER::delete;

  if ( $error ) {
    $dbh->rollback;
    return $error;
  }
  
  $dbh->commit if $oldAutoCommit;
  '';
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

To change the list of linked exports, see the C<export_nas> method.

=cut

sub replace {
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my ($self, $old) = @_;
  $old ||= qsearchs('nas', { 'nasnum' => $self->nasnum });

  my $error;
  foreach my $part_export ( $self->part_export ) {
    $error ||= $part_export->export_nas_replace($self, $old);
  }

  $error ||= $self->SUPER::replace($old);

  if ( $error ) {
    $dbh->rollback;
    return $error;
  }

  $dbh->commit if $oldAutoCommit;
  '';
}

=item check

Checks all fields to make sure this is a valid NAS.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('nasnum')
    || $self->ut_text('nasname')
    || $self->ut_textn('shortname')
    || $self->ut_text('type')
    || $self->ut_numbern('ports')
    || $self->ut_text('secret')
    || $self->ut_textn('server')
    || $self->ut_textn('community')
    || $self->ut_text('description')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_export

Return all L<FS::part_export> objects to which this NAS is being exported.

=cut

sub part_export {
  my $self = shift;
  map { qsearchs('part_export', { exportnum => $_->exportnum }) } 
        qsearch('export_nas', { nasnum => $self->nasnum})
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

