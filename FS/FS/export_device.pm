package FS::export_device;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs dbh );
use FS::part_export;
use FS::part_device;

=head1 NAME

FS::export_device - Object methods for export_device records

=head1 SYNOPSIS

  use FS::export_device;

  $record = new FS::export_device \%hash;
  $record = new FS::export_device { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::export_device object links a device definition (see L<FS::part_device>)
to an export (see L<FS::part_export>).  FS::export_device inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item exportdevicenum - primary key

=item exportnum - export (see L<FS::part_export>)

=item devicepart - device definition (see L<FS::part_device>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'export_device'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# may want to check for duplicates against either services or devices
# cf FS::export_svc

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  $self->ut_numbern('exportdevicenum')
    || $self->ut_number('exportnum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum')
    || $self->ut_number('devicepart')
    || $self->ut_foreign_key('devicepart', 'part_device', 'devicepart')
    || $self->SUPER::check
  ;
}

=item part_export

Returns the FS::part_export object (see L<FS::part_export>).

=cut

sub part_export {
  my $self = shift;
  qsearchs( 'part_export', { 'exportnum' => $self->exportnum } );
}

=item part_device

Returns the FS::part_device object (see L<FS::part_device>).

=cut

sub part_device {
  my $self = shift;
  qsearchs( 'part_device', { 'svcpart' => $self->devicepart } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::part_export>, L<FS::part_device>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

