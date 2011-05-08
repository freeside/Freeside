package FS::part_event::Condition::agent;

use strict;

use base qw( FS::part_event::Condition );

# see the FS::part_event::Condition manpage for full documentation on each
# of the required and optional methods.

sub description {
  'Agent';
}

sub option_fields {
  (
    'agentnum'   => { label=>'Agent', type=>'select-agent', },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);

  my $agentnum = $self->option('agentnum');

  $cust_main->agentnum == $agentnum;

}

sub condition_sql {
  my( $class, $table, %opt ) = @_;

  "cust_main.agentnum = " . $class->condition_sql_option_integer('agentnum', $opt{'driver_name'});
}

1;
