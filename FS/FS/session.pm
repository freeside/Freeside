package FS::session;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::svc_acct;

@ISA = qw(FS::Record);

=head1 NAME

FS::session - Object methods for session records

=head1 SYNOPSIS

  use FS::session;

  $record = new FS::session \%hash;
  $record = new FS::session {
    'portnum' => 1,
    'svcnum'  => 2,
    'login'   => $timestamp,
    'logout'  => $timestamp,
  };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::session object represents an user login session.  FS::session inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item sessionnum - primary key

=item portnum - NAS port for this session - see L<FS::port>

=item svcnum - User for this session - see L<FS::svc_acct>

=item login - timestamp indicating the beginning of this user session.

=item logout - timestamp indicating the end of this user session.  May be null,
               which indicates a currently open session.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'session'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.  If the `login' field is empty, it is replaced with
the current time.

=cut

sub insert {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  $error = $self->check;
  return $error if $error;

  $self->setfield('login', time()) unless $self->getfield('login');

  $error = $self->SUPER::insert;
  return $error if $error;

  #session-starting callback!

  '';

}

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.  If the `logout' field is empty,
it is replaced with the current time.

=cut

sub replace {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  $error = $self->check;
  return $error if $error;

  $self->setfield('logout', time()) unless $self->getfield('logout');

  $error = $self->SUPER::replace;
  return $error if $error;

  #session-ending callback!

  '';
}

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
    $self->ut_numbern('sessionnum')
    || $self->ut_number('portnum')
    || $self->ut_number('svcnum')
    || $self->ut_numbern('login')
    || $self->ut_numbern('logout')
  ;
  return $error if $error;
  return "Unknown svcnum"
    unless qsearchs('svc_acct', { 'svcnum' => $self->svcnum } );
  '';
}

=back

=head1 VERSION

$Id: session.pm,v 1.1 2000-10-27 20:18:32 ivan Exp $

=head1 BUGS

The author forgot to customize this manpage.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

