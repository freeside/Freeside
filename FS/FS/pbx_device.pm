package FS::pbx_device;
use base qw( FS::MAC_Mixin FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::pbx_device - Object methods for pbx_device records

=head1 SYNOPSIS

  use FS::pbx_device;

  $record = new FS::pbx_device \%hash;
  $record = new FS::pbx_device { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::pbx_device object represents a specific customer phone device, such
as a SIP phone or ATA.  FS::pbx_device inherits from FS::Record.  The following fields are currently supported:

=over 4

=item devicenum

primary key

=item devicepart

devicepart

=item svcnum

svcnum

=item mac_addr

mac_addr


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'pbx_device'; }

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
    $self->ut_numbern('devicenum')
    || $self->ut_foreign_key('devicepart', 'part_device', 'devicepart')
    || $self->ut_foreign_key('svcnum', 'svc_pbx', 'svcnum')
    || $self->ut_mac_addr('mac_addr')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

