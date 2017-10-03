package FS::access_user_session_log;
use base qw( FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::access_user_session_log - Object methods for access_user_session_log records

=head1 SYNOPSIS

  use FS::access_user_session_log;

  $record = new FS::access_user_session_log \%hash;
  $record = new FS::access_user_session_log { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::access_user_session_log object represents an log of an employee session.
FS::access_user_session_log inherits from FS::Record.  The following fields
are currently supported:

=over 4

=item sessionlognum

primary key

=item usernum

usernum

=item start_date

start_date

=item last_date

last_date

=item logout_date

logout_date

=item logout_type

logout_type


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new log entry.  To add the entry to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'access_user_session_log'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid log entry.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_number('usernum')
    || $self->ut_numbern('start_date')
    || $self->ut_numbern('last_date')
    || $self->ut_numbern('logout_date')
    || $self->ut_text('logout_type')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

