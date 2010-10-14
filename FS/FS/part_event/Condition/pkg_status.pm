package FS::part_event::Condition::pkg_status;

use strict;

use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );

sub description {
  'Package Status';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 0,
      'cust_pkg'  => 1,
    };
}

#something like this
sub option_fields {
  (
    'status'  => { 'label'    => 'Package Status',
                   'type'     => 'select-cust_pkg-status',
                   'multiple' => 1,
                 },
  );
}

sub condition {
  my( $self, $cust_pkg ) = @_;

  #XXX test
  my $hashref = $self->option('status') || {};
  $hashref->{ $cust_pkg->status };
}

sub condition_sql {
  my( $self, $table ) = @_;

  '('.FS::cust_pkg->status_sql . ') IN '.
  $self->condition_sql_option_option('status');
}

1;
