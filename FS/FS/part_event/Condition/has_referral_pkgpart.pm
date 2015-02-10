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
                    },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  return 0 unless FS::part_event::Condition::has_referral_custnum::condition($self, $object, %opt);

  my $cust_main = $self->cust_main($object);

  my $if_pkgpart = $self->option('if_pkgpart') || {};
  grep $if_pkgpart->{ $_->pkgpart },
    $cust_main->referral_custnum_cust_main->ncancelled_pkgs;
                                            #maybe billing_pkgs
}

#XXX 
#sub condition_sql {
#
#}

1;

