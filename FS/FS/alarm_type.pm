package FS::alarm_type;

use strict;
use base qw( FS::Record );
use FS::Record; # qw( qsearch qsearchs );
use FS::agent;

=head1 NAME

FS::alarm_type - Object methods for alarm_type records

=head1 SYNOPSIS

  use FS::alarm_type;

  $record = new FS::alarm_type \%hash;
  $record = new FS::alarm_type { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::alarm_type object represents an alarm system type (number of inputs and
outputs).  FS::alarm_type inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item alarmtypenum

primary key

=item agentnum

agentnum

=item inputs

inputs

=item outputs

outputs

=item disabled

disabled

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new type.  To add the type to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'alarm_type'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid type.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('alarmtypenum')
    || $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
    || $self->ut_number('inputs')
    || $self->ut_number('outputs')
    || $self->ut_enum('disabled', ['', 'Y'])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item typename

inputs x outputs

=cut

sub typename {
  my $self = shift;
  $self->inputs. 'x'. $self->outputs;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_alarm>, L<FS::Record>

=cut

1;

