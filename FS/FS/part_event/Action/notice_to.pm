package FS::part_event::Action::notice_to;

use strict;
use base qw( FS::part_event::Action );
use FS::Record qw( qsearchs );
use FS::msg_template;

sub description { 'Email a notice to a specific address'; }

#sub eventtable_hashref {
#    { 'cust_main' => 1,
#      'cust_bill' => 1,
#      'cust_pkg'  => 1,
#    };
#}

sub option_fields {
  (
    'to'     => { 'label'    => 'Destination',
                  'type'     => 'text',
                  'size'     => 30,
                },
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
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  my $msgnum = $self->option('msgnum');

  my $msg_template = qsearchs('msg_template', { 'msgnum' => $msgnum } )
      or die "Template $msgnum not found";

  my $to = $self->option('to') 
      or die "Can't send notice without a destination address";
  
  $msg_template->send(
    'to'        => $to,
    'cust_main' => $cust_main,
    'object'    => $object,
  );

}

1;
