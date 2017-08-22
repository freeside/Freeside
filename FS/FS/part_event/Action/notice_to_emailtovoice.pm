package FS::part_event::Action::notice_to_emailtovoice;

use strict;
use base qw( FS::part_event::Action );
use FS::Record qw( qsearchs );
use FS::msg_template;
use FS::Conf;

sub description { 'Email a email to voice notice'; }

sub eventtable_hashref {
    {
      'cust_main'      => 1,
      'cust_bill'      => 1,
      'cust_pkg'       => 1,
      'cust_pay'       => 1,
      'cust_pay_batch' => 1,
      'cust_statement' => 1,
      'svc_acct'       => 1,
    };
}

sub option_fields {

  #my $conf = new FS::Conf;
  #my $to_domain = $conf->config('email-to-voice_domain');

(
    'to_name'   => { 'label'            => 'Address To',
                     'type'             => 'select',
                     'options'          => [ 'mobile', 'fax', 'daytime' ],
                     'option_labels'    => { 'mobile'  => 'Mobile Phone #',
                                             'fax'     => 'Fax #',
                                             'daytime' => 'Day Time #',
                                           },
                     'post_field_label' => "@", # . $to_domain ,
                   },

    'msgnum'    => { 'label'    => 'Template',
                     'type'     => 'select-table',
                     'table'    => 'msg_template',
                     'name_col' => 'msgname',
                     'hashref'  => { disabled => '' },
                     'disable_empty' => 1,
                },
  );

}

sub default_weight { 56; } #?

sub do_action {
  my( $self, $object ) = @_;

  my $conf = new FS::Conf;
  my $to_domain = $conf->config('email-to-voice_domain')
    or die "Can't send notice with out send-to-domain, being set in global config \n";

  my $cust_main = $self->cust_main($object);

  my $msgnum = $self->option('msgnum');
  my $name = $self->option('to_name');

  my $msg_template = qsearchs('msg_template', { 'msgnum' => $msgnum } )
      or die "Template $msgnum not found";

  my $to_name = $cust_main->$name
    or die "Can't send notice with out " . $cust_main->$name . " number set";

  ## remove - from phone number
  $to_name =~ s/-//g;

  #my $to = $to_name . '@' . $self->option('to_domain');
  my $to = $to_name . '@' . $to_domain;
  
  $msg_template->send(
    'to'        => $to,
    'cust_main' => $cust_main,
    'object'    => $object,
  );

}

1;
