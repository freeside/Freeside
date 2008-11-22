package FS::part_event::Condition::pkg_age;

use strict;
use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );

sub description {
  'Package Age';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 0,
      'cust_pkg'  => 1,
    };
}

#something like this
sub option_fields {
  (
    'age'  =>  { 'label'   => 'Package date age',
                 'type'    => 'freq',
               },
    'field' => { 'label'   => 'Compare date',
                 'type'    => 'select',
                 'options' =>
                   [qw( setup last_bill bill adjourn susp expire cancel )],
                 'labels'  => {
                   'setup'     => 'Setup date',
                   'last_bill' => 'Last bill date',
                   'bill'      => 'Next bill date',
                   'adjourn'   => 'Adjournment date',
                   'susp'      => 'Suspension date',
                   'expire'    => 'Expiration date',
                   'cancel'    => 'Cancellation date',
                 },
               },
  );
}

sub condition {
  my( $self, $cust_pkg, %opt ) = @_;

  my $age = $self->option_age_from('age', $opt{'time'} );

  my $pkg_date = $cust_pkg->get( $self->option('field') );

  $pkg_date && $pkg_date <= $age;

}

#XXX write me for efficiency
#sub condition_sql {
#
#}

1;

