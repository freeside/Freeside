package FS::part_event::Action::cust_bill_fsinc_print;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Send invoice to Freeside Inc. for printing and mailing'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'modenum'     => { label  => 'Invoice mode',
                       type   => 'select-invoice_mode',
                     },
  );
}

sub default_weight { 52; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  $cust_bill->set('mode' => $self->option('modenum'));

  my $letter_id = $cust_bill->postal_mail_fsinc;

  #TODO: store this so we can query for a status later
}

1;
