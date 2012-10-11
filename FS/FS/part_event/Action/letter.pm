package FS::part_event::Action::letter;

use strict;
use base qw( FS::part_event::Action );
use FS::Record qw( qsearchs );
use FS::msg_template;

sub description { 'Print a form letter to the customer' }

#sub eventtable_hashref {
#    { 'cust_main' => 1,
#      'cust_bill' => 1,
#      'cust_pkg'  => 1,
#    };
#}

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
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  my $msgnum = $self->option('msgnum');

  my $msg_template = qsearchs('msg_template', { 'msgnum' => $msgnum } )
      or die "Template $msgnum not found";

  $msg_template->print(
    'cust_main' => $cust_main,
    'object'    => $object,
  );

}

1;
