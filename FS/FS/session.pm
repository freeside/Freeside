package FS::session;

use strict;
use vars qw( @ISA $conf $start $stop );
use FS::UID qw( dbh );
use FS::Record qw( qsearchs );
use FS::svc_acct;
use FS::port;
use FS::nas;

@ISA = qw(FS::Record);

$FS::UID::callback{'FS::session'} = sub {
  $conf = new FS::Conf;
  $start = $conf->exists('session-start') ? $conf->config('session-start') : '';
  $stop = $conf->exists('session-stop') ? $conf->config('session-stop') : '';
};

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

  $error = $record->nas_heartbeat($timestamp);

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

Creates a new session.  To add the session to the database, see L<"insert">.

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

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( qsearchs('session', { 'portnum' => $self->portnum, 'logout' => '' } ) ) {
    $dbh->rollback if $oldAutoCommit;
    return "a session on that port is already open!";
  }

  $self->setfield('login', time()) unless $self->getfield('login');

  $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $self->nas_heartbeat($self->getfield('login'));

  #session-starting callback
    #redundant with heartbeat, yuck
  my $port = qsearchs('port',{'portnum'=>$self->portnum});
  my $nas = qsearchs('nas',{'nasnum'=>$port->nasnum});
    #kcuy
  my( $ip, $nasip, $nasfqdn ) = ( $port->ip, $nas->nasip, $nas->nasfqdn );
  system( eval qq("$start") ) if $start;
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
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
  my($self, $old) = @_;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $error = $self->check;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $self->setfield('logout', time()) unless $self->getfield('logout');

  $error = $self->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $self->nas_heartbeat($self->getfield('logout'));

  #session-ending callback
  #redundant with heartbeat, yuck
  my $port = qsearchs('port',{'portnum'=>$self->portnum});
  my $nas = qsearchs('nas',{'nasnum'=>$port->nasnum});
    #kcuy
  my( $ip, $nasip, $nasfqdn ) = ( $port->ip, $nas->nasip, $nas->nasfqdn );
  system( eval qq("$stop") ) if $stop;

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

=item check

Checks all fields to make sure this is a valid session.  If there is
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
  $self->SUPER::check;
}

=item nas_heartbeat

Heartbeats the nas associated with this session (see L<FS::nas>).

=cut

sub nas_heartbeat {
  my $self = shift;
  my $port = qsearchs('port',{'portnum'=>$self->portnum});
  my $nas = qsearchs('nas',{'nasnum'=>$port->nasnum});
  $nas->heartbeat(shift);
}

=item svc_acct

Returns the svc_acct record associated with this session (see L<FS::svc_acct>).

=cut

sub svc_acct {
  my $self = shift;
  qsearchs('svc_acct', { 'svcnum' => $self->svcnum } );
}

=back

=head1 VERSION

$Id: session.pm,v 1.8 2003-08-05 00:20:46 khoff Exp $

=head1 BUGS

Maybe you shouldn't be able to insert a session if there's currently an open
session on that port.  Or maybe the open session on that port should be flagged
as problematic?  autoclosed?  *sigh*

Hmm, sessions refer to current svc_acct records... probably need to constrain
deletions to svc_acct records such that no svc_acct records are deleted which
have a session (even if long-closed).

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

