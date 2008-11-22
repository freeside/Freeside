package FS::part_event::Condition::pkg_pkgpart;

use strict;

use base qw( FS::part_event::Condition );

sub description { 'Package definitions'; }

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 0,
      'cust_pkg'  => 1,
    };
}

sub option_fields {
  ( 
    'if_pkgpart' => { 'label'    => 'Only packages: ',
                      'type'     => 'select-part_pkg',
                      'multiple' => 1,
                    },
  );
}

sub condition {
  my( $self, $cust_pkg) = @_;

  #XXX test
  my $if_pkgpart = $self->option('if_pkgpart') || {};
  $if_pkgpart->{ $cust_pkg->pkgpart };

}

#XXX 
#sub condition_sql {
#
#}

1;
