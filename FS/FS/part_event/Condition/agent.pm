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
    'agentnum'   => { label=>'Agent', type=>'select-agent', multiple => '1' },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);

  my $hashref = $self->option('agentnum') || {};
  grep $hashref->{ $_->agentnum }, $cust_main->agent;

}

sub condition_sql {
  my( $class, $table, %opt ) = @_;

  "cust_main.agentnum IN " . $class->condition_sql_option_option_integer('agentnum', $opt{'driver_name'});
}

1;
