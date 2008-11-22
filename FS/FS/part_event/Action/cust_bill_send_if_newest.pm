package FS::part_event::Action::cust_bill_send_if_newest;

use strict;
use base qw( FS::part_event::Action );

sub description {
  'Send invoice (email/print/fax) with alternate template, if it is still the newest invoice (useful for late notices - set to 31 days or later)';
}

# XXX is this handled better by something against customers??
#sub deprecated {
#  1;
#}

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'if_newest_templatename' => { label    => 'Template',
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
