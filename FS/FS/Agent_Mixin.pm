package FS::Agent_Mixin;

use strict;
use FS::Record qw( qsearchs );
use FS::agent;

=head1 NAME

FS::Agent_Mixin - Mixin class for objects that have an agent.

=over 4

=item agent

Returns the agent (see L<FS::agent>) for this object.

=cut

sub agent {
  my $self = shift;
  qsearchs( 'agent', { 'agentnum' => $self->agentnum } );
}

=item agent_name

Returns the agent name (see L<FS::agent>) for this object.

=cut

sub agent_name {
  my $self = shift;
  $self->agent->agent;
}

=back

=head1 BUGS

=cut

1;

