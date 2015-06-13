package FS::part_event::Action::cust_bill_spool_csv;

use strict;
use base qw( FS::part_event::Action );
use FS::Misc::Invoicing qw( spool_formats );

sub description { 'Spool CSV invoice data'; }

sub deprecated { 1; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'spoolformat'       => { label   => 'Format',
                             type    => 'select',
                             options => [ spool_formats() ],
                           },
    'spoolbalanceover'  => { label =>
                               'If balance (this invoice and previous) over',
                             type  => 'money',
                           },
    'spoolagent_spools' => { label => 'Individual per-agent spools',
                             type  => 'checkbox',
                             value => '1',
                           },
    'upload_targetnum'  => { label    => 'Upload spool to target',
                             type     => 'select-table',
                             table    => 'upload_target',
                             name_col => 'label',
                             empty_label => '(do not upload)',
                             order_by => 'targetnum',
                           },
    'skip_nopost' => { label => 'Skip customers without postal billing enabled',
                       type  => 'checkbox',
                       value => 'Y',
                     },
  );
}

sub default_weight { 50; }

sub do_action {
  my( $self, $cust_bill, $cust_event ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  return if $self->option('skip_nopost')
         && ! grep { $_ eq 'POST' } $cust_main->invoicing_list;

  $cust_bill->spool_csv(
    'time'         => $cust_event->_date,
    'format'       => $self->option('spoolformat'),
    'balanceover'  => $self->option('spoolbalanceover'),
    'agent_spools' => $self->option('spoolagent_spools'),
    'upload_targetnum'=> $self->option('upload_targetnum'),
  );
}

1;
