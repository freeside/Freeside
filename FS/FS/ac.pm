package FS::ac;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs qsearch );
use FS::ac_type;
use FS::ac_block;

@ISA = qw( FS::Record );

=head1 NAME

FS::ac - Object methods for ac records

=head1 SYNOPSIS

  use FS::ac;

  $record = new FS::ac \%hash;
  $record = new FS::ac { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::ac record describes a broadband Access Concentrator, such as a DSLAM
or a wireless access point.  FS::ac inherits from FS::Record.  The following 
fields are currently supported:

narf

=over 4

=item acnum - primary key

=item actypenum - AC type, see L<FS::ac_type>

=item acname - descriptive name for the AC

=back

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'ac'; }

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

  my $error =
    $self->ut_numbern('acnum')
    || $self->ut_number('actypenum')
    || $self->ut_text('acname');
  return $error if $error;

  return "Unknown actypenum"
    unless $self->ac_type;
  '';
}

=item ac_type

Returns the L<FS::ac_type> object corresponding to this object.

=cut

sub ac_type {
  my $self = shift;
  return qsearchs('ac_type', { actypenum => $self->actypenum });
}

=item ac_block

Returns a list of L<FS::ac_block> objects (address blocks) associated
with this object.

=cut

sub ac_block {
  my $self = shift;
  return qsearch('ac_block', { acnum => $self->acnum });
}

=item ac_field

Returns a hash of L<FS::ac_field> objects assigned to this object.

=cut

sub ac_field {
  my $self = shift;

  return qsearch('ac_field', { acnum => $self->acnum });
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

