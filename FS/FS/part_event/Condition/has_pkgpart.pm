package FS::part_event::Condition::has_pkgpart;
use base qw( FS::part_event::Condition );

use strict;

sub description { 'Customer has uncancelled specific package(s)'; }

sub eventtable_hashref {
    { 'cust_main' => 1,
      'cust_bill' => 1,
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
  my( $self, $object) = @_;

  my $cust_main = $self->cust_main($object);

  my $if_pkgpart = $self->option('if_pkgpart') || {};
  grep $if_pkgpart->{ $_->pkgpart },
         $cust_main->ncancelled_pkgs( 'skip_label_sort'=>1 );

}

sub condition_sql {
  my( $self, $table ) = @_;

  'ARRAY'. $self->condition_sql_option_option_integer('if_pkgpart').
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
