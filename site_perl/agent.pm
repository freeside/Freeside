package FS::agent;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(fields qsearch qsearchs);
use FS::cust_main;
use FS::agent_type;

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

=head1 NAME

FS::agent - Object methods for agent records

=head1 SYNOPSIS

  use FS::agent;

  $record = create FS::agent \%hash;
  $record = create FS::agent { 'column' => 'value' };

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

=item create HASHREF

Creates a new agent.  To add the agent to the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('agent')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('agent',$hashref);
}

=item insert

Adds this agent to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  $self->check or
  $self->add;
}

=item delete

Deletes this agent from the database.  Only agents with no customers can be
deleted.  If there is an error, returns the error, otherwise returns false.

=cut

sub delete {
  my($self)=@_;
  return "Can't delete an agent with customers!"
    if qsearch('cust_main',{'agentnum' => $self->agentnum});
  $self->del;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not an agent record!" unless $old->table eq "agent";
  return "Can't change agentnum!"
    unless $old->getfield('agentnum') eq $new->getfield('agentnum');
  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid agent.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my($self)=@_;
  return "Not a agent record!" unless $self->table eq "agent";

  my($error)=
    $self->ut_numbern('agentnum')
      or $self->ut_text('agent')
      or $self->ut_number('typenum')
      or $self->ut_numbern('freq')
      or $self->ut_textn('prog')
  ;
  return $error if $error;

  return "Unknown typenum!"
    unless qsearchs('agent_type',{'typenum'=> $self->getfield('typenum') });

  '';

}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

=head1 SEE ALSO

L<FS::Record>, L<FS::agent_type>, L<FS::cust_main>, schema.html from the base
documentation.

=head1 HISTORY

Class dealing with agent (resellers)

ivan@sisd.com 97-nov-13, 97-dec-10

pod, added check in ->delete ivan@sisd.com 98-sep-22

=cut

1;

