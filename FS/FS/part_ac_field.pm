package FS::part_ac_field;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::ac_field;
use FS::ac;


@ISA = qw( FS::Record );

=head1 NAME

FS::part_ac_field - Object methods for part_ac_field records

=head1 SYNOPSIS

  use FS::part_ac_field;

  $record = new FS::part_ac_field \%hash;
  $record = new FS::part_ac_field { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION


=over 4

=item blank

=back

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'part_ac_field'; }

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
  my $error = '';

  $self->name =~ /^([a-z0-9_\-\.]{1,15})$/i
    or return "Invalid field name for part_ac_field";

  ''; #no error
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

