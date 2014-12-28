package FS::part_event::Action::cust_bill_print;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Send invoice (print only)'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'modenum' => {  label => 'Invoice mode',
                    type  => 'select-invoice_mode',
                 },
    'skip_nopost' => { label => 'Skip customers without postal billing enabled',
                       type  => 'checkbox',
                     },
  );
}

sub default_weight { 51; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  $cust_bill->set('mode' => $self->option('modenum'));
  $cust_bill->print unless $self->option('skip_nopost')
                        && ! grep { $_ eq 'POST' } $cust_main->invoicing_list;
}

1;
