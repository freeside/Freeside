package FS::part_event::Condition::cust_status;

use strict;

use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );

sub description {
  'Customer Status';
}

#something like this
sub option_fields {
  (
    'status'  => { 'label'    => 'Customer Status',
                   'type'     => 'select-cust_main-status',
                   'multiple' => 1,
                 },
  );
}

sub condition {
  my( $self, $object) = @_;

  my $cust_main = $self->cust_main($object);

  #XXX test
  my $hashref = $self->option('status') || {};
  $hashref->{ $cust_main->status };
}

sub condition_sql {
  my( $self, $table ) = @_;

  '('.FS::cust_main->cust_status_sql . ') IN '.
    $self->condition_sql_option_option('status');
}


1;
