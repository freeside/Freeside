package FS::part_event::Action::cust_bill_send_with_notice;

use strict;
use base qw( FS::part_event::Action );
use FS::msg_template;
use MIME::Entity;

sub description { 'Email a notice to the customer with invoice attached'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'msgnum'      => { label  => 'Message template',
                       type     => 'select-table',
                       table    => 'msg_template',
                       hashref  => { disabled => '' },
                       name_col => 'msgname',
                       disable_empty => 1,
                     },
    'modenum'     => { label  => 'Invoice mode',
                       type   => 'select-invoice_mode',
                     },

  );
}

sub default_weight { 56; }

sub do_action {
  my( $self, $cust_bill, %opt ) = @_;

  $cust_bill->set('mode' => $self->option('modenum'));
  my %args = ( 'time' => $opt{'time'} );
  my $mimepart = MIME::Entity->build( $cust_bill->mimebuild_pdf(\%args) );
  my $msgnum = $self->option('msgnum');
  my $msg_template = FS::msg_template->by_key($msgnum)
    or die "can't find message template #$msgnum to send with invoice";
  $msg_template->send(
    'cust_main' => $cust_bill->cust_main,
    'object'    => $cust_bill,
    'attach'    => $mimepart
  );
}

1;
