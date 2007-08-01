package FS::part_event::Condition::agent_type;

use strict;

use base qw( FS::part_event::Condition );

# see the FS::part_event::Condition manpage for full documentation on each
# of the required and optional methods.

sub description {
  'Agent Type';
}

sub option_fields {
  (
    'typenum'   => { label         => 'Agent Type',
                     type          => 'select-agent_type',
                     disable_empty => 1,
                   },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);

  my $typenum = $self->option('typenum');

  $cust_main->agent->typenum == $typenum;

}

#sub condition_sql {
#  my( $self, $table ) = @_;
#
#  'true';
#}

1;
