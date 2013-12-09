package FS::alarm_system;

use strict;
use base qw( FS::Record );
use FS::Record; # qw( qsearch qsearchs );
use FS::agent;

=head1 NAME

FS::alarm_system - Object methods for alarm_system records

=head1 SYNOPSIS

  use FS::alarm_system;

  $record = new FS::alarm_system \%hash;
  $record = new FS::alarm_system { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::alarm_system object represents an alarm system vendor.  FS::alarm_system
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item alarmsystemnum

primary key

=item agentnum

agentnum

=item systemname

systemname

=item disabled

disabled


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new vendor.  To add the vendor to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'alarm_system'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid vendor.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('alarmsystemnum')
    || $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
    || $self->ut_text('systemname')
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

