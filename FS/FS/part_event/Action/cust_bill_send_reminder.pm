package FS::part_event::Action::cust_bill_send_reminder;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Send invoice (email/print/fax) reminder'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'modenum' => {  label => 'Invoice mode',
                    type  => 'select-invoice_mode',
                 },
    # totally unnecessary, since the invoice mode can set notice_name and lpr,
    # but for compatibility...
    'notice_name' => 'Reminder name',
    #'notes'      => { 'label' => 'Reminder notes' },  # invoice mode does this
    'lpr'         => 'Optional alternate print command',
  );
}

sub default_weight { 50; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  $cust_bill->set('mode' => $self->option('modenum'));
  $cust_bill->send({
    'notice_name' => $self->option('notice_name'),
    'lpr'         => $self->option('lpr'),
  });
}

1;
