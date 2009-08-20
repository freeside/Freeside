package FS::part_event::Condition::hasnt_pkgpart;

use strict;

use base qw( FS::part_event::Condition );

sub description { 'Customer does not have uncancelled package of specified definitions'; }

sub eventtable_hashref {
    { 'cust_main' => 1,
      'cust_bill' => 1,
      'cust_pkg'  => 1,
    };
}

sub option_fields {
  ( 
    'unless_pkgpart' => { 'label'    => 'Packages: ',
                          'type'     => 'select-part_pkg',
                          'multiple' => 1,
                        },
  );
}

sub condition {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  #XXX test
  my $unless_pkgpart = $self->option('unless_pkgpart') || {};
  ! grep $unless_pkgpart->{ $_->pkgpart }, $cust_main->ncancelled_pkgs;
}

#XXX
#sub condition_sql {
#
#}

1;
