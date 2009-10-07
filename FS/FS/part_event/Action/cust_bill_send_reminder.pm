package FS::part_event::Action::cust_bill_send_reminder;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Send invoice (email/print/fax) reminder'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'notice_name'  => 'Reminder name',
    #'notes' => { 'label' => 'Reminder notes' }, 
    #include standard notes?  no/prepend/append
  );
}

sub default_weight { 50; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  #my $cust_main = $cust_bill->cust_main;

  $cust_bill->send({ 'notice_name' => $self->option('notice_name') });
}

1;
