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
                             options => ['default', 'billco'],
                             option_labels => { 'default' => 'Default',
                                                'billco'  => 'Billco',
                                              },
                           },
    'spooldest'         => { label   => 'For destination',
                             type    => 'select',
                             options => [ '', qw( POST EMAIL FAX ) ],
                             option_labels => { ''      => '(all)',
                                                'POST'  => 'Postal Mail',
                                                'EMAIL' => 'Email',
                                                'FAX'   => 'Fax',
                                              },
                           },
    'spoolbalanceover'  => { label =>
                               'If balance (this invoice and previous) over',
                             type  => 'money',
                           },
    'spoolagent_spools' => { label => 'Individual per-agent spools',
                             type  => 'checkbox',
                             value => 'Y',
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
    'dest'         => $self->option('spooldest'),
    'balanceover'  => $self->option('spoolbalanceover'),
    'agent_spools' => $self->option('spoolagent_spools'),
  );
}

1;
