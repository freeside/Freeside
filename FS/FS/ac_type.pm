package FS::ac_type;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::ac;

@ISA = qw( FS::Record );

=head1 NAME

FS::ac_type - Object methods for ac_type records

=head1 SYNOPSIS

  use FS::ac_type;

  $record = new FS::ac_type \%hash;
  $record = new FS::ac_type { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

L<FS::ac_type> refers to a type of access concentrator.  L<FS::svc_broadband>
records refer to a specific L<FS::ac_type> limiting the choice of access
concentrator to one of the chosen type.  This should be set as a fixed
default in part_svc to prevent provisioning the wrong type of service for
a given package or service type.  Supported fields as follows:

=over 4

=item actypenum - Primary key.  see L<FS::ac>

=item actypename - Text identifier for access concentrator type.

=back

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'ac_type'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this record from the database.  If there is an error, returns the
error, otherwise returns false.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  # What do we check?

  ''; #no error
}

=item ac

Returns a list of all L<FS::ac> records of this type.

=cut

sub ac {
  my $self = shift;

  return qsearch('ac', { actypenum => $self->actypenum });
}

=item part_ac_field

Returns a list of all L<FS::part_ac_field> records of this type.

=cut

sub part_ac_field {
  my $self = shift;

  return qsearch('part_ac_field', { actypenum => $self->actypenum });
}

=back

=head1 VERSION

$Id: 

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_broadband>, L<FS::ac>, L<FS::ac_block>, L<FS::ac_field>,  schema.html
from the base documentation.

=cut

1;

