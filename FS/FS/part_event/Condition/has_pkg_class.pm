package FS::part_event::Condition::has_pkg_class;

use strict;

use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );
use FS::pkg_class;

sub description {
  'Customer has uncancelled package with class';
}

sub eventtable_hashref {
    { 'cust_main' => 1,
      'cust_bill' => 1,
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
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  #XXX test
  my $hashref = $self->option('pkgclass') || {};
  grep $hashref->{ $_->part_pkg->classnum }, $cust_main->ncancelled_pkgs;
}

1;
