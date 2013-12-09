package FS::alarm_station;

use strict;
use base qw( FS::Record );
use FS::Record; # qw( qsearch qsearchs );
use FS::agent;

=head1 NAME

FS::alarm_station - Object methods for alarm_station records

=head1 SYNOPSIS

  use FS::alarm_station;

  $record = new FS::alarm_station \%hash;
  $record = new FS::alarm_station { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::alarm_station object represents an alarm system central station.
FS::alarm_station inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item alarmstationnum

primary key

=item agentnum

agentnum

=item stationname

stationname

=item disabled

disabled


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new central station.  To add the central station to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'alarm_station'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid central station.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('alarmstationnum')
    || $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
    || $self->ut_text('stationname')
    || $self->ut_enum('disabled', ['', 'Y'])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_alarm>, L<FS::Record>

=cut

1;

