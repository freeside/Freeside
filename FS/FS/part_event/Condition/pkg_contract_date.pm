package FS::part_event::Condition::pkg_contract_date;
use base qw( FS::part_event::Condition );

use strict;

sub description {
  'Package contract date nearing';
}

sub eventtable_hashref {
    {
      'cust_pkg'       => 1,
    };
}

sub option_fields {
  my $class = shift;
  (
    'within'  =>  { 'label'   => 'Package contract date with in',
                    'type'    => 'freq',
                  },
  );
}

sub condition {
  my( $self, $cust_pkg, %opt ) = @_;
  
  my $contract_end_date = $cust_pkg->contract_end ? $cust_pkg->contract_end : 0;
  my $contract_within_time = $self->option_age_from('within', $contract_end_date );

  $opt{'time'} >= $contract_within_time and $contract_within_time > 0;
}

1;