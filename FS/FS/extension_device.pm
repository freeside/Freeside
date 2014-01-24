package FS::extension_device;
use base qw( FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::extension_device - Object methods for extension_device records

=head1 SYNOPSIS

  use FS::extension_device;

  $record = new FS::extension_device \%hash;
  $record = new FS::extension_device { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::extension_device object represents a PBX extension association with a 
specific PBX device (SIP phone or ATA).  FS::extension_device inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item extensiondevicenum

primary key

=item extensionnum

extensionnum

=item devicenum

devicenum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'extension_device'; }

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
    $self->ut_numbern('extensiondevicenum')
    || $self->ut_foreign_keyn('extensionnum', 'pbx_extension', 'extensionnum')
    || $self->ut_foreign_keyn('devicenum', 'pbx_device', 'devicenum')
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

