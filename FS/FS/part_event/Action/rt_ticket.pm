package FS::part_event::Action::rt_ticket;

use strict;
use base qw( FS::part_event::Action );
use FS::Record qw( qsearchs );
use FS::msg_template;

sub description { 'Open an RT ticket for the customer' }

#need to be valid for msg_template substitution
sub eventtable_hashref {
    { 'cust_main'      => 1,
      'cust_bill'      => 1,
      'cust_pkg'       => 1,
      'cust_pay'       => 1,
      'svc_acct'       => 1,
    };
}

sub option_fields {
  (
    'msgnum'    => { 'label'    => 'Template',
                     'type'     => 'select-table',
                     'table'    => 'msg_template',
                     'name_col' => 'msgname',
                     'hashref'  => { disabled => '', msgclass => 'email' },
                     'disable_empty' => 1,
                   },
    'queueid'   => { 'label' => 'Queue',
                     'type'  => 'select-rt-queue',
                   },
    'requestor' => { 'label'   => 'Requestor',
                     'type'    => 'select',
                     'options' => [ 0, 1 ],
                     'labels'  => {
                       0 => 'Customer\'s invoice address',
                       1 => 'Template From: address',
                     },
                   },

  );
}

sub default_weight { 59; }

sub do_action {

  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object)
    or die "Could not load cust_main";

  my $msgnum = $self->option('msgnum');
  my $msg_template = qsearchs('msg_template', { 'msgnum' => $msgnum } )
    or die "Template $msgnum not found";

  my $queueid = $self->option('queueid')
    or die "No queue specified";

  # technically this only works if create_ticket is implemented,
  # and it is only implemented in RT_Internal,
  # but we can let create_ticket throw that error
  my $conf = new FS::Conf;
  die "rt_ticket event - no ticket system configured"
    unless $conf->config('ticket_system');
  
  FS::TicketSystem->init();

  my $cust_msg = $msg_template->prepare(
    'cust_main' => $cust_main,
    'object'    => $object,
  );

  my $subject = $cust_msg->entity->head->get('Subject');
  chomp($subject);

  my $requestor = $self->option('requestor')
                ? $msg_template->from_addr
                : [ $cust_main->invoicing_list_emailonly ];

  my $svcnum = ref($object) eq 'FS::svc_acct'
             ? $object->svcnum
             : undef;

  my $err_or_ticket = FS::TicketSystem->create_ticket(
    '', #session should already exist
    'queue'     => $queueid,
    'subject'   => $subject,
    'requestor' => $requestor,
    'message'   => $cust_msg->preview,
    'mime_type' => 'text/html',
    'custnum'   => $cust_main->custnum,
    'svcnum'    => $svcnum,
  );
  die $err_or_ticket unless ref($err_or_ticket);
  return '';

}

1;
