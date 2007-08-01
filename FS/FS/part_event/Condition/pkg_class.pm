package FS::part_event::Condition::pkg_class;

use strict;

use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );
use FS::pkg_class;

sub description {
  'Package Class';
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
    'pkgclass'  => { 'label'    => 'Package Class',
                     'type'     => 'select-pkg_class',
                     'multiple' => 1,
                   },
  );
}

sub condition {
  my( $self, $cust_pkg ) = @_;

  #XXX test
  my $hashref = $self->option('pkgclass') || {};
  $hashref->{ $cust_pkg->part_pkg->classnum };
}

1;
