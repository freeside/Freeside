package FS::circuit_termination;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::circuit_termination - Object methods for circuit_termination records

=head1 SYNOPSIS

  use FS::circuit_termination;

  $record = new FS::circuit_termination \%hash;
  $record = new FS::circuit_termination { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::circuit_termination object represents a central office circuit 
interface type.  FS::circuit_termination inherits from FS::Record.  The 
following fields are currently supported:

=over 4

=item termnum - primary key

=item termination - description of the termination type

=item disabled - 'Y' if this is disabled

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

=cut

sub table { 'circuit_termination'; }

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
    $self->ut_numbern('termnum')
    || $self->ut_text('termination')
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

