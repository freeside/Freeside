package FS::ac_field;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::part_ac_field;
use FS::ac;

use UNIVERSAL qw( can );

@ISA = qw( FS::Record );

=head1 NAME

FS::ac_field - Object methods for ac_field records

=head1 SYNOPSIS

  use FS::ac_field;

  $record = new FS::ac_field \%hash;
  $record = new FS::ac_field { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

L<FS::ac_field> contains values of fields defined by L<FS::part_ac_field>
for an L<FS::ac>.  Values must be of the data type defined by ut_type in
L<FS::part_ac_field>.
Supported fields as follows:

=over 4

=item acfieldpart - Type of ac_field as defined by L<FS::part_ac_field>

=item acnum - The L<FS::ac> to which this value belongs.

=item value - The contents of the field.

=back

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'ac_field'; }

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

  return "acnum must be defined" unless $self->acnum;
  return "acfieldpart must be defined" unless $self->acfieldpart;

  my $ut_func = $self->can("ut_" . $self->part_ac_field->ut_type);
  my $error = $self->$ut_func('value');

  return $error if $error;

  ''; #no error
}

=item part_ac_field

Returns a reference to the L<FS:part_ac_field> that defines this L<FS::ac_field>

=cut

sub part_ac_field {
  my $self = shift;

  return qsearchs('part_ac_field', { acfieldpart => $self->acfieldpart });
}

=item ac

Returns a reference to the L<FS::ac> to which this L<FS::ac_field> belongs.

=cut

sub ac {
  my $self = shift;

  return qsearchs('ac', { acnum => $self->acnum });
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

