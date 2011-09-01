package FS::part_event::Action::svc_acct_notice;

use strict;
use base qw( FS::part_event::Action );
use FS::Record qw( qsearchs );
use FS::svc_acct;
use FS::msg_template;

sub description { 'Email a notice to this account'; }

sub eventtable_hashref {
  { 'svc_acct' => 1 }
};

sub option_fields {
  (
    'msgnum' => { 'label'    => 'Template',
                  'type'     => 'select-table',
                  'table'    => 'msg_template',
                  'name_col' => 'msgname',
                  'disable_empty' => 1,
                },
  );
}

sub default_weight { 56; } #?

sub do_action {
  my( $self, $svc_acct ) = @_;

  my $cust_main = $self->cust_main($svc_acct)
      or die "No customer found for svcnum ".$svc_acct->svcnum;
    # this will never be run for unlinked services, for several reasons

  my $msgnum = $self->option('msgnum');

  my $msg_template = qsearchs('msg_template', { 'msgnum' => $msgnum } )
      or die "Template $msgnum not found";

  my $email = $svc_acct->email
      or die "No email associated with svcnum ".$svc_acct->svcnum;

  $msg_template->send(
    'cust_main' => $cust_main,
    'object'    => $svc_acct,
    'to'        => $email,
  );

}

1;
