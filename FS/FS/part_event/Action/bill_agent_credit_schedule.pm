package FS::part_event::Action::bill_agent_credit_schedule;

use base qw( FS::part_event::Action );
use FS::Conf;
use FS::cust_credit;
use FS::commission_schedule;
use Date::Format qw(time2str);

use strict;

sub description { 'Credit the agent based on a commission schedule' }

sub option_fields {
  'schedulenum' => { 'label'        => 'Schedule',
                     'type'         => 'select-table',
                     'table'        => 'commission_schedule',
                     'name_col'     => 'schedulename',
                     'disable_empty'=> 1,
                   },
}

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

our $date_format;

sub do_action {
  my( $self, $cust_bill, $cust_event ) = @_;

  $date_format ||= FS::Conf->new->config('date_format') || '%x';

  my $cust_main = $self->cust_main($cust_bill);
  my $agent = $cust_main->agent;
  return "No customer record for agent ". $agent->agent
    unless $agent->agent_custnum;

  my $agent_cust_main = $agent->agent_cust_main;

  my $schedulenum = $self->option('schedulenum')
    or return "no commission schedule selected";
  my $schedule = FS::commission_schedule->by_key($schedulenum)
    or return "commission schedule #$schedulenum not found";
    # commission_schedule::delete tries to prevent this, but just in case

  my $amount = $schedule->calc_credit($cust_bill)
    or return;

  my $reasonnum = $schedule->reasonnum;

  #XXX shouldn't do this here, it's a localization problem.
  # credits with commission_invnum should know how to display it as part
  # of invoice rendering.
  my $desc = 'from invoice #'. $cust_bill->display_invnum .
             ' ('. time2str($date_format, $cust_bill->_date) . ')';
             # could also show custnum and pkgnums here?
  my $cust_credit = FS::cust_credit->new({
    'custnum'             => $agent_cust_main->custnum,
    'reasonnum'           => $reasonnum,
    'amount'              => $amount,
    'eventnum'            => $cust_event->eventnum,
    'addlinfo'            => $desc,
    'commission_agentnum' => $cust_main->agentnum,
    'commission_invnum'   => $cust_bill->invnum,
  });
  my $error = $cust_credit->insert;
  die "Error crediting customer ". $agent_cust_main->custnum.
      " for agent commission: $error"
    if $error;

  #return $warning; # currently don't get warnings here
  return;

}

1;
