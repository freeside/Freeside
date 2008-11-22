package FS::part_event::Condition::pkg_unless_pkgpart;

use strict;

use base qw( FS::part_event::Condition );

sub description { 'Except package definitions'; }

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 0,
      'cust_pkg'  => 1,
    };
}

sub option_fields {
  ( 
    'unless_pkgpart' => { 'label'    => 'Except packages: ',
                          'type'     => 'select-part_pkg',
                          'multiple' => 1,
                        },
  );
}

sub condition {
  my( $self, $cust_pkg) = @_;

  #XXX test
  my $unless_pkgpart = $self->option('unless_pkgpart') || {};
  ! $unless_pkgpart->{ $cust_pkg->pkgpart };

}

#XXX
#sub condition_sql {
#
#}

1;
