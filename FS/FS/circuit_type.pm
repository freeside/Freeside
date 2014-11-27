package FS::circuit_type;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::circuit_type - Object methods for circuit_type records

=head1 SYNOPSIS

  use FS::circuit_type;

  $record = new FS::circuit_type \%hash;
  $record = new FS::circuit_type { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::circuit_type object represents a circuit type (such as "DS1" or "OC3").
FS::circuit_type inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item typenum - primary key

=item typename - name of the circuit type

=item disabled - 'Y' if this is disabled

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

=cut

sub table { 'circuit_type'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('typenum')
    || $self->ut_text('typename')
    || $self->ut_flag('disabled')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>

=cut

1;

