package FS::part_event::Condition::pkg_dundate_age;
use base qw( FS::part_event::Condition );

use strict;

sub description {
  "Skip until specified #days before package suspension delay date";
}


sub option_fields {
  (
    'age'     => { 'label'      => 'Time before suspension delay date',
                   'type'       => 'freq',
                 },
  );
}

sub eventtable_hashref {
  { 'cust_main' => 0,
    'cust_bill' => 0,
    'cust_pkg'  => 1,
  };
}

sub condition {
  my($self, $cust_pkg, %opt) = @_;

  my $age = $self->option_age_from('age', $opt{'time'} );

  $cust_pkg->dundate <= $age;
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;
  return 'true' unless $table eq 'cust_pkg';
  
  my $age = $class->condition_sql_option_age_from('age', $opt{'time'});
  
  "COALESCE($table.dundate,0) <= ". $age;
}

1;
