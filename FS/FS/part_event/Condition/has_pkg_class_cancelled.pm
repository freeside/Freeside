package FS::part_event::Condition::has_pkg_class_cancelled;
use base qw( FS::part_event::Condition );

use strict;

sub description {
  'Customer has canceled package with class';
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
    'age'       => { 'label'      => 'Cacnellation in last',
                     'type'       => 'freq',
                   },
  );
}

sub condition {
  my( $self, $object, %opt ) = @_;

  my $cust_main = $self->cust_main($object);

  my $age = $self->option_age_from('age', $opt{'time'} );

  #XXX test
  my $hashref = $self->option('pkgclass') || {};
  grep { $hashref->{ $_->part_pkg->classnum } && $_->get('cancel') > $age }
    $cust_main->cancelled_pkgs;
}

1;
