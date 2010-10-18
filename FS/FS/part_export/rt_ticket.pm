package FS::part_export::rt_ticket;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;
use FS::Record qw(qsearch qsearchs);
use FS::Conf;
use FS::TicketSystem;
use Data::Dumper 'Dumper';

@ISA = qw(FS::part_export);

my %templates;
my %queues;
my %template_select = (
  type          => 'select',
  option_label  => sub {
    $templates{$_[0]};
  },
  option_values => sub {
    %templates = (0 => '',
      map { $_->msgnum, $_->msgname } 
      qsearch({ table => 'msg_template',
                hashref => {},
                order_by => 'ORDER BY msgnum ASC'
              })
    );
    sort keys (%templates);
  },
);

tie my %options, 'Tie::IxHash', (
  'queue' => {
    label     => 'Queue',
    type      => 'select',
    option_label  => sub {
      $queues{$_[0]};
    },
    option_values => sub {
      %queues = FS::TicketSystem->queues();
      sort {$queues{$a} cmp $queues{$b}} keys %queues;
    },
  },
  'insert_template' => {
    label     => 'Insert',
    %template_select
  },
  'replace_template' => {
    label     => 'Replace',
    %template_select
  },
  'delete_template' => {
    label     => 'Delete',
    %template_select
  },
  'suspend_template' => {
    label     => 'Suspend',
    %template_select
  },
  'unsuspend_template' => {
    label     => 'Unsuspend',
    %template_select
  },
  'requestor' => {
    label     => 'Requestor',
    'type'    => 'select',
    option_label => sub {
      my @labels = (
        'Template From: address',
        'Customer\'s invoice address',
      );
      $labels[shift];
    },
    option_values => sub { (0, 1) },
  },
);

%info = (
  'svc'      => [qw( svc_acct )], #others?
  'desc'     =>
    'Create an RT ticket',
  'options'  => \%options,
  'nodomain' => '',
  'notes'    => <<'END'
Create a ticket in RT.  The subject and body of the ticket 
will be generated from a message template.
END
);

sub _export_ticket {
  my( $self, $action, $svc ) = (shift, shift, shift);
  my $msgnum = $self->option($action.'_template');
  return if !$msgnum;

  my $msg_template = FS::msg_template->by_key($msgnum);
  return "Template $msgnum not found\n" if !$msg_template;

  my $cust_pkg = $svc->cust_svc->cust_pkg;
  my $cust_main = $svc->cust_svc->cust_pkg->cust_main if $cust_pkg;
  my $custnum = $cust_main->custnum if $cust_main;
  my $svcnum = $svc->svcnum if $action ne 'delete';

  my %msg;
  if ( $action eq 'replace' ) {
    my $old = shift;
    %msg = $msg_template->prepare(
      'cust_main' => $cust_main,
      'object'    => [ $svc, $old ],
    );

  }
  else {
    %msg = $msg_template->prepare(
      'cust_main' => $cust_main,
      'object'    => $svc,
    );
  }
  my $requestor = $msg{'from'};
  $requestor = [ $cust_main->invoicing_list_emailonly ]
    if $cust_main and $self->option('requestor') == 1;

  my $err_or_ticket = FS::TicketSystem->create_ticket(
    '', #session should already exist
    'queue'     => $self->option('queue'),
    'subject'   => $msg{'subject'},
    'requestor' => $requestor,
    'message'   => $msg{'html_body'},
    'mime_type' => 'text/html',
    'custnum'   => $custnum,
    'svcnum'    => $svcnum,
  );
  if( ref($err_or_ticket) ) {
    return '';
  }
  else {
    return $err_or_ticket;
  }
}

sub _export_insert {
  my($self, $svc) = (shift, shift);
  $self->_export_ticket('insert', $svc);
}

sub _export_replace {
  my($self, $new, $old) = (shift, shift, shift);
  $self->_export_ticket('replace', $new, $old);
}

sub _export_delete {
  my($self, $svc) = (shift, shift);
  $self->_export_ticket('delete', $svc);
}

sub _export_suspend {
  my($self, $svc) = (shift, shift);
  $self->_export_ticket('suspend', $svc);
}

sub _export_unsuspend {
  my($self, $svc) = (shift, shift);
  $self->_export_ticket('unsuspend', $svc);
}

1;
