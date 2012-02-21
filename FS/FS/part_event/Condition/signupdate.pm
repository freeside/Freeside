package FS::part_event::Condition::signupdate;

use strict;
use base qw( FS::part_event::Condition );
use FS::Record qw(str2time_sql str2time_sql_closing);
use Date::Parse 'str2time';

sub description { 'Customer signed up during date range' }

sub option_fields {
  (
    # actually stored as strings
    'start' => {  label   => 'First day',
                  type    => 'date',
                  format  => '%Y-%m-%d', },
    'end'   => {  label => 'Last day',
                  type  => 'date', 
                  format  => '%Y-%m-%d', },
  );
}

sub condition {

  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);
  my $start = $self->option('start');
  my $end = $self->option('end');

  (!$start or $cust_main->signupdate >= str2time($start)) and
  (!$end   or $cust_main->signupdate <  str2time($end) + 86400);
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;
  return 'true' if $opt{'driver_name'} ne 'Pg';

  my $start = $class->condition_sql_option('start');
  my $end = $class->condition_sql_option('end');

  $start = "$start IS NULL OR cust_main.signupdate >=" . 
           str2time_sql . "($start)::timestamp" . str2time_sql_closing;
  $end   = "$end IS NULL OR cust_main.signupdate < 86400 + " . 
           str2time_sql . "($end)::timestamp" . str2time_sql_closing;
  "($start) AND ($end)";
}

1;
