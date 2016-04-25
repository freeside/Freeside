package FS::part_event::Condition::day_of_week;

use strict;
use base qw( FS::part_event::Condition );
use FS::Record qw( dbh );

tie my %dayofweek, 'Tie::IxHash', 
  0 => 'Sunday',
  1 => 'Monday',
  2 => 'Tuesday',
  3 => 'Wednesday',
  4 => 'Thursday',
  5 => 'Friday',
  6 => 'Saturday',
;

sub description {
  "Run only on certain days of the week",
}

sub option_fields {
  (
    'dayofweek' => {
       label         => 'Days to run',
       type          => 'checkbox-multiple',
       options       => [ values %dayofweek ],
       option_labels => { map { $_ => $_ } values %dayofweek },
    },
  );
}

sub condition { # is this even necessary? condition_sql is exact.
  my( $self, $object, %opt ) = @_;

  my $today = $dayofweek{(localtime($opt{'time'}))[6]};
  if (grep { $_ eq $today } (keys %{$self->option('dayofweek')})) {
    return 1;
  }
  '';
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;
  my $today = $dayofweek{(localtime($opt{'time'}))[6]};
  my $day = $class->condition_sql_option_option('dayofweek');
  return dbh->quote($today) . " IN $day";
}

1;
