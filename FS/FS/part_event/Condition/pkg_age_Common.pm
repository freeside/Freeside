package FS::part_event::Condition::pkg_age_Common;
use base qw( FS::part_event::Condition );

use strict;
use Tie::IxHash;

tie our %dates, 'Tie::IxHash',
  'setup'        => 'Setup date',
  'last_bill'    => 'Last bill date',
  'bill'         => 'Next bill date',
  'adjourn'      => 'Adjournment date',
  'susp'         => 'Suspension date',
  'expire'       => 'Expiration date',
  'cancel'       => 'Cancellation date',
  'contract_end' => 'Contract end date',
;

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 0,
      'cust_pkg'  => 1,
    };
}

#something like this
sub option_fields {
  my $class = shift;
  (
    'age'  =>  { 'label'   => $class->pkg_age_label,
                 'type'    => 'freq',
               },
    'field' => { 'label'   => 'Compare date',
                 'type'    => 'select',
                 'options' => [ keys %dates ],
                 'labels'  => \%dates,
               },
  );
}

sub condition {
  my( $self, $cust_pkg, %opt ) = @_;

  my $age = $self->pkg_age_age( $cust_pkg, %opt );

  my $pkg_date = $cust_pkg->get( $self->option('field') );

  $pkg_date && $self->pkg_age_compare( $pkg_date, $age );

}

sub pkg_age_age {
  my( $self, $cust_pkg, %opt );
  $self->option_age_from('age', $opt{'time'} );
}

#doesn't work if you override pkg_age_age,
# so if you do, override this with at least a stub that returns 'true'
sub condition_sql {
  my( $class, $table, %opt ) = @_;
  my $age   = $class->condition_sql_option_age_from('age', $opt{'time'});
  my $field = $class->condition_sql_option('field');
  my $op    = $class->pkg_age_operator;

  #amazingly, this is actually faster 
  my $sql = '( CASE';
  foreach ( keys %dates ) {
    $sql .= " WHEN $field = '$_' THEN ".
            "  (cust_pkg.$_ IS NOT NULL AND cust_pkg.$_ $op $age)";
  }
  $sql .= ' END )';
  return $sql;
}

1;

