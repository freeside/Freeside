package FS::part_event::Action::cust_bill_email;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Send invoice (email only)'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'modenum' => {  label => 'Invoice mode',
                    type  => 'select-invoice_mode',
                 },
  );
}

sub default_weight { 51; }

sub do_action {
  my( $self, $cust_bill, $cust_event ) = @_;

  my $cust_main = $cust_bill->cust_main;

  $cust_bill->set('mode' => $self->option('modenum'));
  if ( $cust_main->invoice_noemail ) {
    # what about if the customer has no email dest?
    $cust_event->set('no_action', 'Y');
    return "customer has invoice_noemail flag";
  } else {
    $cust_bill->email;
  }
}

1;
