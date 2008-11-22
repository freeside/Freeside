package FS::part_event::Action::cust_bill_send_agent;

use strict;
use base qw( FS::part_event::Action );

sub description {
  'Send invoice (email/print/fax) with alternate template, for specific agents';
}

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'agentnum'           => { label    => 'Only for agent(s)',
                              type     => 'select-agent',
                              multiple => 1
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

  $cust_bill->send(
    $self->option('agent_templatename'),
    [ split(/\s*,\s*/, $self->option('agentnum') ) ],
    $self->option('agent_invoice_from'),
  );
}

1;
