package FS::part_export::send_email;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;
use FS::Record qw(qsearch qsearchs);
use FS::Conf;
use FS::msg_template;
use FS::Misc qw(send_email);

@ISA = qw(FS::part_export);

my %templates;
my %template_select = (
  type          => 'select',
  freeform      => 1,
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
  'insert_template' => {
    before  => '
<TR><TD COLSPAN=2>
<TABLE>
  <TR><TH></TH><TH>Template</TH></TR>
  <TR><TD>New service</TD><TD>',
    %template_select,
    after   => '</TD></TR>
',
  },
  'delete_template' => {
    before  => '
  <TR><TD>Delete</TD><TD>',
    %template_select,
    after   => '</TD></TR>
',
  },
  'replace_template' => {
    before => '
  <TR><TD>Modify</TD><TD>',
    %template_select,
    after   => '</TD></TR>
',
  },
  'suspend_template' => {
    before  => '
  <TR><TD>Suspend</TD><TD>',
    %template_select,
    after   => '</TD></TR>
',
  },
  'unsuspend_template' => {
    before  => '
  <TR><TD>Unsuspend</TD><TD>',
    %template_select,
    after   => '</TD></TR>
  </TABLE>
</TD></TR>',
  },
  'to_customer' => {
    label   => 'Send to customer',
    type    => 'checkbox',
  },
  'to_address' => {
    label => 'Send to other address: ',
    type      => 'text',
  },
);

%info = (
  'svc'      => [qw( svc_acct svc_broadband svc_phone svc_domain )],
  'desc'     =>
  'Send an email message',
  'options'  => \%options,
  'nodomain' => '',
  'notes'    => ' 
  Send an email message.  The subject and body of the message
  will be generated from a message template.'
);

sub _export {
  my( $self, $action, $svc ) = (shift, shift, shift);
  my $conf = new FS::Conf;

  my $msgnum = $self->option($action.'_template');
  return if !$msgnum;

  my $msg_template = FS::msg_template->by_key($msgnum);
  return "Template $msgnum not found\n" if !$msg_template;

  my $cust_pkg = $svc->cust_svc->cust_pkg;
  my $cust_main = $svc->cust_svc->cust_pkg->cust_main if $cust_pkg;
  my $custnum = $cust_main->custnum if $cust_main;
  my $svcnum = $svc->svcnum if $action ne 'delete';

  my @to = split(',', $self->option('to_address') || '');
  push @to, $cust_main->invoicing_list_emailonly 
    if $self->option('to_customer') and $cust_main;
  if ( !@to ) {
    warn 'No destination address for send_email export: custnum '.$cust_main->custnum;
    # warn, don't die, but also avoid sending the template with _no_ 'to'=> 
    # param, which would send to the customer by default.
    return;
  }

  if ( $action eq 'replace' ) {
    my $old = shift;
    return $msg_template->send(
      'cust_main' => $cust_main,
      'object'    => [ $svc, $old ],
      'to'        => join(',', @to),
    );
  }
  else {
    return $msg_template->send(
      'cust_main' => $cust_main,
      'object'    => $svc,
      'to'        => join(',', @to),
    );
  }
}

sub _export_insert {
  my($self, $svc) = (shift, shift);
  $self->_export('insert', $svc);
}

sub _export_replace {
  my($self, $new, $old) = (shift, shift, shift);
  $self->_export('replace', $new, $old);
}

sub _export_delete {
  my($self, $svc) = (shift, shift);
  $self->_export('delete', $svc);
}

sub _export_suspend {
  my($self, $svc) = (shift, shift);
  $self->_export('suspend', $svc);
}

sub _export_unsuspend {
  my($self, $svc) = (shift, shift);
  $self->_export('unsuspend', $svc);
}

1;
