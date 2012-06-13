package FS::part_event::Action::cust_bill_spool_csv;

use strict;
use base qw( FS::part_event::Action );
use FS::Misc;

sub description { 'Spool CSV invoice data'; }

sub deprecated { 1; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'spoolformat'       => { label   => 'Format',
                             type    => 'select',
                             options => [ FS::Misc::spool_formats() ],
                           },
    'spoolbalanceover'  => { label =>
                               'If balance (this invoice and previous) over',
                             type  => 'money',
                           },
    'spoolagent_spools' => { label => 'Individual per-agent spools',
                             type  => 'checkbox',
                             value => '1',
                           },
    'ftp_targetnum'     => { label    => 'Upload spool to FTP target',
                             type     => 'select-table',
                             table    => 'ftp_target',
                             name_col => 'label',
                             empty_label => '(do not upload)',
                             order_by => 'targetnum',
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
    'ftp_targetnum'=> $self->option('ftp_targetnum'),
  );
}

1;
