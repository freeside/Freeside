package FS::part_event::Action::cust_bill_spool_csv;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Spool CSV invoice data'; }

sub deprecated { 1; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'spoolformat'       => { label   => 'Format',
                             type    => 'select',
                             options => ['default', 'billco', 'oneline'],
                             option_labels => { 'default' => 'Default',
                                                'billco'  => 'Billco',
                                                'oneline' => 'One line',
                                              },
                           },
    'spoolbalanceover'  => { label =>
                               'If balance (this invoice and previous) over',
                             type  => 'money',
                           },
    'spoolagent_spools' => { label => 'Individual per-agent spools',
                             type  => 'checkbox',
                             value => '1',
                           },
  );
}

sub default_weight { 50; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  $cust_bill->spool_csv(
    'format'       => $self->option('spoolformat'),
    'balanceover'  => $self->option('spoolbalanceover'),
    'agent_spools' => $self->option('spoolagent_spools'),
  );
}

1;
