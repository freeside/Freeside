package FS::part_event::Condition::balance_age;

require 5.006;
use strict;
use Time::Local qw(timelocal_nocheck);

use base qw( FS::part_event::Condition );

sub description { 'Customer balance age'; }

sub option_fields {
  (
    'balance' => { 'label'      => 'Balance over',
                   'type'       => 'money',
                   'value'      => '0.00', #default
                 },
    'age'     => { 'label'      => 'Age',
                   'type'       => 'freq',
                 },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);

  my $over = $self->option('balance');
  $over = 0 unless length($over);

  #false laziness w/cust_bill_age
  my $time = $opt{'time'};
  my $age = $self->option('age');
  $age = '0m' unless length($age);

  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($time) )[0,1,2,3,4,5];
  if ( $age =~ /^(\d+)m$/i ) {
    $mon -= $1;
    until ( $mon >= 0 ) { $mon += 12; $year--; }
  } elsif ( $age =~ /^(\d+)y$/i ) {
    $year -= $1;
  } elsif ( $age =~ /^(\d+)w$/i ) {
    $mday -= $1 * 7;
  } elsif ( $age =~ /^(\d+)d$/i ) {
    $mday -= $1;
  } elsif ( $age =~ /^(\d+)h$/i ) {
    $hour -= $hour;
  } else {
    die "unparsable age: $age";
  }
  my $age_date = timelocal_nocheck($sec,$min,$hour,$mday,$mon,$year);

  $cust_main->balance_date($age_date) > $over;
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;

  my $over    = $class->condition_sql_option('balance');
  my $age     = $class->condition_sql_option_age_from('age', $opt{'time'});

  my $balance_sql = FS::cust_main->balance_date_sql( $age );

  "$balance_sql > $over";
}

sub order_sql {
  shift->condition_sql_option_age('age');
}

use FS::UID qw( driver_name );

sub order_sql_weight {
  10;
}

1;
