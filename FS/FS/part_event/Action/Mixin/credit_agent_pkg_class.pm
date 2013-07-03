package FS::part_event::Action::Mixin::credit_agent_pkg_class;
use base qw( FS::part_event::Action::Mixin::credit_pkg );

use strict;
use FS::Record qw(qsearchs);

sub option_fields {
  my $class = shift;
  my %option_fields = $class->SUPER::option_fields;
  delete $option_fields{'percent'};
  %option_fields;
}

sub _calc_credit_percent {
  my( $self, $cust_pkg ) = @_;

  my $agent_pkg_class = qsearchs( 'agent_pkg_class', {
    'agentnum' => $self->cust_main($cust_pkg)->agentnum,
    'classnum' => $cust_pkg->part_pkg->classnum,
  });

  $agent_pkg_class ? $agent_pkg_class->commission_percent : 0;

}

1;
