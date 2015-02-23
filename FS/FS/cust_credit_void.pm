package FS::cust_credit_void; 

use strict;
use base qw( FS::otaker_Mixin FS::cust_main_Mixin FS::Record );
use FS::Record qw(qsearch qsearchs dbh fields);
use FS::CurrentUser;
use FS::access_user;
use FS::cust_credit;
use FS::UID qw( dbh );

=head1 NAME

FS::cust_credit_void - Object methods for cust_credit_void objects

=head1 SYNOPSIS

  use FS::cust_credit_void;

  $record = new FS::cust_credit_void \%hash;
  $record = new FS::cust_credit_void { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_credit_void object represents a voided credit.  All fields in
FS::cust_credit are present, as well as:

=over 4

=item void_date - the date (unix timestamp) that the credit was voided

=item void_reason - the reason (a freeform string)

=item void_usernum - the user (L<FS::access_user>) who voided it

=back

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new voided credit record.

=cut

sub table { 'cust_credit_void'; }

=item insert

Adds this voided credit to the database.

=item check

Checks all fields to make sure this is a valid voided credit.  If there is an
error, returns the error, otherwise returns false.  Called by the insert
method.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('crednum')
    || $self->ut_number('custnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('amount')
    || $self->ut_alphan('otaker')
    || $self->ut_textn('reason')
    || $self->ut_textn('addlinfo')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->ut_foreign_keyn('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_foreign_keyn('eventnum', 'cust_event', 'eventnum')
    || $self->ut_foreign_keyn('commission_agentnum',  'agent', 'agentnum')
    || $self->ut_foreign_keyn('commission_salesnum',  'sales', 'salesnum')
    || $self->ut_foreign_keyn('commission_pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_numbern('void_date')
    || $self->ut_textn('void_reason')
    || $self->ut_foreign_keyn('void_usernum', 'access_user', 'usernum')
    || $self->ut_foreign_keyn('void_reasonnum', 'reason', 'reasonnum')
  ;
  return $error if $error;

  $self->void_date(time) unless $self->void_date;

  $self->void_usernum($FS::CurrentUser::CurrentUser->usernum)
    unless $self->void_usernum;

  $self->SUPER::check;
}

=item unvoid 

"Un-void"s this credit: Deletes the voided credit from the database and adds
back (but does not re-apply) a normal credit.

=cut

sub unvoid {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_credit = new FS::cust_credit ( {
    map { $_ => $self->get($_) } grep { $_ !~ /void/ } $self->fields
  } );
  my $error = $cust_credit->insert;

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $error ||= $self->delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item cust_main

Returns the parent customer object (see L<FS::cust_main>).

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
}

=item void_access_user

Returns the voiding employee object (see L<FS::access_user>).

=cut

sub void_access_user {
  my $self = shift;
  qsearchs('access_user', { 'usernum' => $self->void_usernum } );
}

=item void_access_user_name

Returns the voiding employee name.

=cut

sub void_access_user_name {
  my $self = shift;
  my $user = $self->void_access_user;
  return unless $user;
  return $user->name;
}

=item void_reason

Returns the text of the associated void credit reason (see L<FS::reason>) for this voided credit.

The reason for the original credit remains accessible through the reason method.

=cut

sub void_reason {
  my ($self, $value, %options) = @_;
  my $reason_text;
  if ( $self->void_reasonnum ) {
    my $reason = FS::reason->by_key($self->void_reasonnum);
    $reason_text = $reason->reason;
  } else { # in case one of these somehow still exists
    $reason_text = $self->get('void_reason');
  }

  return $reason_text;
}

=back

=head1 BUGS

Doesn't yet support unvoid.

=head1 SEE ALSO

L<FS::cust_credit>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

