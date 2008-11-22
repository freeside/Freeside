package FS::part_event::Action::cust_bill_send_alternate;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Send invoice (email/print/fax) with alternate template'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'templatename' => { label    => 'Template',
                        type     => 'select-invoice_template',
                      },
  );
}

sub default_weight { 50; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  $cust_bill->send( $self->option('templatename') );
}

1;
