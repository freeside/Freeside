package FS::part_referral;

use strict;
use vars qw( @ISA $setup_hack );
use FS::Record qw( qsearch qsearchs dbh );
use FS::agent;

@ISA = qw( FS::Record );
$setup_hack = 0;

=head1 NAME

FS::part_referral - Object methods for part_referral objects

=head1 SYNOPSIS

  use FS::part_referral;

  $record = new FS::part_referral \%hash
  $record = new FS::part_referral { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_referral represents a advertising source - where a customer heard
of your services.  This can be used to track the effectiveness of a particular
piece of advertising, for example.  FS::part_referral inherits from FS::Record.
The following fields are currently supported:

=over 4

=item refnum - primary key (assigned automatically for new referrals)

=item referral - Text name of this advertising source

=item disabled - Disabled flag, empty or 'Y'

=item agentnum - Optional agentnum (see L<FS::agent>)

=back

=head1 NOTE

These were called B<referrals> before version 1.4.0 - the name was changed
so as not to be confused with the new customer-to-customer referrals.

=head1 METHODS

=over 4

=item new HASHREF

Creates a new advertising source.  To add the referral to the database, see
L<"insert">.

=cut

sub table { 'part_referral'; }

=item insert

Adds this advertising source to the database.  If there is an error, returns
the error, otherwise returns false.

=item delete

Currently unimplemented.

=cut

sub delete {
  my $self = shift;
  return "Can't (yet?) delete part_referral records";
  #need to make sure no customers have this referral!
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid advertising source.  If there is
an error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my $self = shift;

  my $error = $self->ut_numbern('refnum')
    || $self->ut_text('referral')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    #|| $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
    || ( $setup_hack
           ? $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum' )
           : $self->ut_agentnum_acl('agentnum', 'Edit global advertising sources')
       )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item agent 

Returns the associated agent for this referral, if any, as an FS::agent object.

=cut

sub agent {
  my $self = shift;
  qsearchs('agent', { 'agentnum' => $self->agentnum } );
}

=back

=head1 CLASS METHODS

=over 4

=item acl_agentnum_sql [ INCLUDE_GLOBAL_BOOL ]

Returns an SQL fragment for searching for part_referral records allowed by the
current users's agent ACLs (and "Edit global advertising sources" right).

Pass a true value to include global advertising sources (for example, when
simply using rather than editing advertising sources).

=cut

sub acl_agentnum_sql {
  my $self = shift;

  my $curuser = $FS::CurrentUser::CurrentUser;
  my $sql = $curuser->agentnums_sql;
  $sql = " ( $sql OR agentnum IS NULL ) "
    if $curuser->access_right('Edit global advertising sources')
    or defined($_[0]) && $_[0];

  $sql;

}

=item all_part_referral [ INCLUDE_GLOBAL_BOOL ]

Returns all part_referral records allowed by the current users's agent ACLs
(and "Edit global advertising sources" right).

Pass a true value to include global advertising sources (for example, when
simply using rather than editing advertising sources).

=cut

sub all_part_referral {
  my $self = shift;

  qsearch({
    'table'     => 'part_referral',
    'extra_sql' => ' WHERE '. $self->acl_agentnum_sql(@_). ' ORDER BY refnum ',
  });

}

=item num_part_referral [ INCLUDE_GLOBAL_BOOL ]

Returns the number of part_referral records allowed by the current users's
agent ACLs (and "Edit global advertising sources" right).

=cut

sub num_part_referral {
  my $self = shift;

  my $sth = dbh->prepare(
    'SELECT COUNT(*) FROM part_referral WHERE '. $self->acl_agentnum_sql(@_)
  ) or die dbh->errstr;
  $sth->execute() or die $sth->errstr;
  $sth->fetchrow_arrayref->[0];
}

=back

=head1 BUGS

The delete method is unimplemented.

`Advertising source'.  Yes, it's a sucky name.  The only other ones I could
come up with were "Marketing channel" and "Heard Abouts" and those are
definately both worse.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, schema.html from the base documentation.

=cut

1;

