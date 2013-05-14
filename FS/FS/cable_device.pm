package FS::cable_device;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearchs ); # qsearch );
use FS::part_device;
use FS::svc_cable;

=head1 NAME

FS::cable_device - Object methods for cable_device records

=head1 SYNOPSIS

  use FS::cable_device;

  $record = new FS::cable_device \%hash;
  $record = new FS::cable_device { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cable_device object represents a specific customer cable modem.
FS::cable_device inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item devicenum

primary key

=item devicepart

devicepart

=item svcnum

svcnum

=item mac_addr

mac_addr

=item serial

serial


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cable_device'; }

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

  my $mac = $self->mac_addr;
  $mac =~ s/\s+//g;
  $mac =~ s/://g;
  $self->mac_addr($mac);

  my $error = 
    $self->ut_numbern('devicenum')
    || $self->ut_number('devicepart')
    || $self->ut_foreign_key('devicepart', 'part_device', 'devicepart')
    || $self->ut_foreign_key('svcnum', 'svc_cable', 'svcnum' ) #cust_svc?
    || $self->ut_hexn('mac_addr')
    || $self->ut_textn('serial')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_device

Returns the device type record (see L<FS::part_device>) associated with this
customer device.

=cut

sub part_device {
  my $self = shift;
  qsearchs( 'part_device', { 'devicepart' => $self->devicepart } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

