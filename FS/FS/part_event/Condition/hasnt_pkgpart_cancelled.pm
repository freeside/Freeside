package FS::part_event::Condition::hasnt_pkgpart_cancelled;
use base qw( FS::part_event::Condition );

use strict;

sub description { 'Customer does not have canceled specific package(s)'; }

sub eventtable_hashref {
    { 'cust_main' => 1,
      'cust_bill' => 1,
      'cust_pkg'  => 1,
    };
}

sub option_fields {
  ( 
    'if_pkgpart' => { 'label'    => 'Packages: ',
                      'type'     => 'select-part_pkg',
                      'multiple' => 1,
                    },
    'age'        => { 'label'      => 'Cancellation in last',
                      'type'       => 'freq',
                    },
  );
}

sub condition {
  my( $self, $object, %opt ) = @_;

  my $cust_main = $self->cust_main($object);

  my $age = $self->option_age_from('age', $opt{'time'} );

  my $if_pkgpart = $self->option('if_pkgpart') || {};
  ! grep { $if_pkgpart->{ $_->pkgpart } && $_->get('cancel') > $age }
    $cust_main->cancelled_pkgs;

}

#XXX 
#sub condition_sql {
#
#}

1;

