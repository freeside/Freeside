package FS::part_event::Condition::pkg_class;

use strict;

use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );
use FS::pkg_class;

sub description {
  'Package Class';
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

  # interpretation depends on the eventtable
  my $hashref = $self->option('pkgclass') || {};
  if ( $object->isa('FS::cust_pkg') ) {
    # is this package in that class?
    $hashref->{ $object->part_pkg->classnum };
  }
  elsif ( $object->isa('FS::cust_main') ) {
    # does this customer have an active package in that class?
    grep { $hashref->{ $_->part_pkg->classnum } } $object->ncancelled_pkgs;
  }
  elsif ( $object->isa('FS::cust_bill') ) {
    # does a package of that class appear on this invoice?
    grep { $hashref->{ $_->part_pkg->classnum } } $object->cust_pkg;
  }
}

1;
