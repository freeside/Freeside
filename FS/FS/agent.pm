package FS::agent;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::agent_type;

@ISA = qw( FS::Record );

=head1 NAME

FS::agent - Object methods for agent records

=head1 SYNOPSIS

  use FS::agent;

  $record = new FS::agent \%hash;
  $record = new FS::agent { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $agent_type = $record->agent_type;

  $hashref = $record->pkgpart_hashref;
  #may purchase $pkgpart if $hashref->{$pkgpart};

=head1 DESCRIPTION

An FS::agent object represents an agent.  Every customer has an agent.  Agents
can be used to track things like resellers or salespeople.  FS::agent inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item agentnum - primary key (assigned automatically for new agents)

=item agent - Text name of this agent

=item typenum - Agent type.  See L<FS::agent_type>

=item prog - For future use.

=item freq - For future use.

=item disabled - Disabled flag, empty or 'Y'

=item username - Username for the Agent interface

=item _password - Password for the Agent interface

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new agent.  To add the agent to the database, see L<"insert">.

=cut

sub table { 'agent'; }

=item insert

Adds this agent to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this agent from the database.  Only agents with no customers can be
deleted.  If there is an error, returns the error, otherwise returns false.

=cut

sub delete {
  my $self = shift;

  return "Can't delete an agent with customers!"
    if qsearch( 'cust_main', { 'agentnum' => $self->agentnum } );

  $self->SUPER::delete;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid agent.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('agentnum')
      || $self->ut_text('agent')
      || $self->ut_number('typenum')
      || $self->ut_numbern('freq')
      || $self->ut_textn('prog')
  ;
  return $error if $error;

  if ( $self->dbdef_table->column('disabled') ) {
    $error = $self->ut_enum('disabled', [ '', 'Y' ] );
    return $error if $error;
  }

  if ( $self->dbdef_table->column('username') ) {
    $error = $self->ut_alphan('username');
    return $error if $error;
    if ( length($self->username) ) {
      my $conflict = qsearchs('agent', { 'username' => $self->username } );
      return 'duplicate agent username (with '. $conflict->agent. ')'
        if $conflict;
      $error = $self->ut_text('password'); # ut_text... arbitrary choice
    } else {
      $self->_password('');
    }
  }

  return "Unknown typenum!"
    unless $self->agent_type;

  $self->SUPER::check;
}

=item agent_type

Returns the FS::agent_type object (see L<FS::agent_type>) for this agent.

=cut

sub agent_type {
  my $self = shift;
  qsearchs( 'agent_type', { 'typenum' => $self->typenum } );
}

=item pkgpart_hashref

Returns a hash reference.  The keys of the hash are pkgparts.  The value is
true if this agent may purchase the specified package definition.  See
L<FS::part_pkg>.

=cut

sub pkgpart_hashref {
  my $self = shift;
  $self->agent_type->pkgpart_hashref;
}

=back

=head1 VERSION

$Id: agent.pm,v 1.6 2003-09-30 15:01:46 ivan Exp $

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::agent_type>, L<FS::cust_main>, L<FS::part_pkg>, 
schema.html from the base documentation.

=cut

1;

