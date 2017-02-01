package FS::part_event::Condition::has_referral_pkgpart;
use base qw( FS::part_event::Condition );

use FS::part_event::Condition::has_referral_custnum;
#maybe i should be incorporated in has_referral_custnum

use strict;

sub description { 'Customer has a referring customer with uncancelled specific package(s)'; }

sub option_fields {
  ( 
    'if_pkgpart' => { 'label'    => 'Only packages: ',
                      'type'     => 'select-part_pkg',
                      'multiple' => 1,
                      'toggle_disabled' => 1,
                    },
  );
}

#lots of falze laziness w/has_pkgpart..

sub condition {
  my($self, $object, %opt) = @_;

  return 0 unless FS::part_event::Condition::has_referral_custnum::condition($self, $object, %opt);

  my $cust_main = $self->cust_main($object);

  my $if_pkgpart = $self->option('if_pkgpart') || {};
  grep $if_pkgpart->{ $_->pkgpart },
    $cust_main->referral_custnum_cust_main->ncancelled_pkgs( 'skip_label_sort'=> 1);
                                            #maybe billing_pkgs
}

sub condition_sql {
  my( $self, $table ) = @_;

  'ARRAY'. $self->condition_sql_option_option_integer('if_pkgpart').
  ' && '. #overlap (have elements in common)
  'ARRAY( SELECT pkgpart FROM cust_pkg AS has_referral_pkgpart_cust_pkg
            WHERE has_referral_pkgpart_cust_pkg.custnum = cust_main.referral_custnum
              AND (    has_referral_pkgpart_cust_pkg.cancel IS NULL
                    OR has_referral_pkgpart_cust_pkg.cancel = 0
                  )
        )
  ';
}

1;

