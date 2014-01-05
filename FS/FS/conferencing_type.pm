package FS::conferencing_type;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::conferencing_type - Object methods for conferencing_type records

=head1 SYNOPSIS

  use FS::conferencing_type;

  $record = new FS::conferencing_type \%hash;
  $record = new FS::conferencing_type { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::conferencing_type object represents a conferencing type.
FS::conferencing_type inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item conftypenum

primary key

=item typeid

Numeric (vendor) ID for type type

=item typename

Name for this type

=item disabled

Empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'conferencing_type'; }

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
    $self->ut_numbern('conftypenum')
    || $self->ut_number('typeid')
    || $self->ut_text('typename')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_conferencing>, L<FS::Record>

=cut

1;

