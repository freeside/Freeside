package FS::part_event::Action::Mixin::credit_agent_pkg_class;

# calculates a credit percentage on a specific package for use with 
# credit_pkg or credit_bill, based on an agent's commission table

use strict;
use FS::Record qw(qsearchs);

sub _calc_credit_percent {
  my( $self, $cust_pkg, $agent ) = @_;

  my $agent_pkg_class = qsearchs( 'agent_pkg_class', {
    'agentnum' => $agent->agentnum,
    'classnum' => $cust_pkg->part_pkg->classnum,
  });

  $agent_pkg_class ? $agent_pkg_class->commission_percent : 0;

}

1;
