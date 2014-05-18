package FS::part_event::Condition::day_of_month;

use strict;
use base qw( FS::part_event::Condition );

sub description {
  "Run only on a certain day of the month",
}

sub option_fields {
  (
    'day'   => { label  => 'Day (1-28, separate multiple days with commas)',
                 type   => 'text',
               },
  );
}

sub condition { # is this even necessary? condition_sql is exact.
  my( $self, $object, %opt ) = @_;

  my $today = (localtime($opt{'time'}))[3];
  if (grep { $_ == $today } split(',', $self->option('day'))) {
    return 1;
  }
  '';
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;
  my $today = (localtime($opt{'time'}))[3];
  my $day = $class->condition_sql_option('day');
  "$today = ANY( string_to_array($day, ',')::integer[] )"
}

1;
