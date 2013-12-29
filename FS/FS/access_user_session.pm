package FS::access_user_session;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::access_user_session - Object methods for access_user_session records

=head1 SYNOPSIS

  use FS::access_user_session;

  $record = new FS::access_user_session \%hash;
  $record = new FS::access_user_session { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::access_user_session object represents a backoffice web session.
FS::access_user_session inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item sessionnum

Database primary key

=item sessionkey

Session key

=item usernum

Employee (see L<FS::access_user>)

=item start_date

Session start timestamp

=item last_date

Last session activity timestamp

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new session.  To add the session to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'access_user_session'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid session.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('sessionnum')
    || $self->ut_text('sessionkey')
    || $self->ut_foreign_key('usernum', 'access_user', 'usernum')
    || $self->ut_number('start_date')
    || $self->ut_numbern('last_date')
  ;
  return $error if $error;

  $self->last_date( $self->start_date ) unless $self->last_date;

  $self->SUPER::check;
}

=item access_user

Returns the employee (see L<FS::access_user>) for this session.

=item touch_last_date

=cut

sub touch_last_date {
  my $self = shift;
  my $old_last_date = $self->last_date;
  $self->last_date(time);
  return if $old_last_date >= $self->last_date;
  my $error = $self->replace;
  die $error if $error;
}

=item logout

=cut

sub logout {
  my $self = shift;
  my $error = $self->delete;
  die $error if $error;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

