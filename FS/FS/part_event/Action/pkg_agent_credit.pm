package FS::part_event::Action::pkg_agent_credit;

use strict;
use base qw( FS::part_event::Action::pkg_referral_credit );

sub description { 'Credit the agent a specific amount'; }

#a little false laziness w/pkg_referral_credit
sub do_action {
  my( $self, $cust_pkg ) = @_;

  my $cust_main = $self->cust_main($cust_pkg);

  my $agent = $cust_main->agent;
  return "No customer record for agent ". $agent->agent
    unless $agent->agent_custnum;

  my $agent_cust_main = $agent->agent_cust_main;
    #? or return "No customer record for agent ". $agent->agent;

  my $amount    = $self->_calc_credit($cust_pkg);
  return '' unless $amount > 0;

  my $reasonnum = $self->option('reasonnum');

  my $error = $agent_cust_main->credit(
    $amount, 
    \$reasonnum,
    'addlinfo' =>
      'for customer #'. $cust_main->display_custnum. ': '.$cust_main->name,
  );
  die "Error crediting customer ". $agent_cust_main->custnum.
      " for agent commission: $error"
    if $error;

}

1;
