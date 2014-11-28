package FS::circuit_provider;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::circuit_provider - Object methods for circuit_provider records

=head1 SYNOPSIS

  use FS::circuit_provider;

  $record = new FS::circuit_provider \%hash;
  $record = new FS::circuit_provider { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::circuit_provider object represents a telecom carrier that provides
physical circuits (L<FS::svc_circuit>).  FS::circuit_provider inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item providernum - primary key

=item provider - provider name

=item disabled - disabled

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'circuit_provider'; }

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

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('providernum')
    || $self->ut_text('provider')
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

