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

=head1 DESCRIPTION

An FS::agent object represents an agent.  Every customer has an agent.  Agents
can be used to track things like resellers or salespeople.  FS::agent inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item agemtnum - primary key (assigned automatically for new agents)

=item agent - Text name of this agent

=item typenum - Agent type.  See L<FS::agent_type>

=item prog - For future use.

=item freq - For future use.

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

  return "Unknown typenum!"
    unless qsearchs( 'agent_type', { 'typenum' => $self->typenum } );

  '';

}

=back

=head1 VERSION

$Id: agent.pm,v 1.4 1998-12-30 00:30:44 ivan Exp $

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::agent_type>, L<FS::cust_main>, schema.html from the base
documentation.

=head1 HISTORY

Class dealing with agent (resellers)

ivan@sisd.com 97-nov-13, 97-dec-10

pod, added check in ->delete ivan@sisd.com 98-sep-22

=cut

1;

