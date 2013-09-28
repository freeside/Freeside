package FS::part_event::Action::cust_bill_send_agent;

use strict;
use base qw( FS::part_event::Action );

sub description {
  'Send invoice (email/print/fax) with alternate template, for specific agents';
}

# this event is just cust_bill_send_alternate + an implicit (and inefficient)
# 'agent' condition

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'agentnum'           => { label    => 'Only for agent(s)',
                              type     => 'select-agent',
                              multiple => 1
                            },
    'modenum' => {  label => 'Invoice mode',
                    type  => 'select-invoice_mode',
                 },
    'agent_templatename' => { label    => 'Template',
                              type     => 'select-invoice_template',
                            },
    'agent_invoice_from' => 'Invoice email From: address',
  );
}

sub default_weight { 50; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  my %agentnums = map { $_=>1 } split(/\s*,\s*/, $self->option('agentnum'));
  if (keys(%agentnums) and !exists($agentnums{$cust_main->agentnum})) {
    return;
  }

  $cust_bill->set('mode' => $self->option('modenum'));
  $cust_bill->send(
    'template'      => $self->option('agent_templatename'),
    'invoice_from'  => $self->option('agent_invoice_from'),
  );
}

1;
