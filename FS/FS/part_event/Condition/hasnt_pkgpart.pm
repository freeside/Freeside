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

#false laziness w/has_pkgpart.pm

sub condition {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  my $unless_pkgpart = $self->option('unless_pkgpart') || {};
  ! grep $unless_pkgpart->{ $_->pkgpart }, $cust_main->ncancelled_pkgs;
}

sub condition_sql {
  my( $self, $table ) = @_;

  'NOT '.
  'ARRAY'. $self->condition_sql_option_option_integer('unless_pkgpart').
  ' && '. #overlap (have elements in common)
  'ARRAY( SELECT pkgpart FROM cust_pkg AS has_pkgpart_cust_pkg
            WHERE has_pkgpart_cust_pkg.custnum = cust_main.custnum
              AND (    has_pkgpart_cust_pkg.cancel IS NULL
                    OR has_pkgpart_cust_pkg.cancel = 0
                  )
        )
  ';
}

1;
