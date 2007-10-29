package FS::part_event::Condition::cust_bill_age;

require 5.006;
use strict;
use Time::Local qw(timelocal_nocheck);

use base qw( FS::part_event::Condition );

sub description {
  'Invoice age';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

#something like this
sub option_fields {
  (
    #'days' => { label=>'Days', size=>3, },
    'age' => { label=>'Age', type=>'freq', },
  );
}

sub condition {
  my( $self, $cust_bill, %opt ) = @_;

  #false laziness w/balance_age
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

  $cust_bill->_date <= $age_date;

}

#                            and seconds <= $time - cust_bill._date

sub condition_sql {
  my( $class, $table, %opt ) = @_;

  my $age  = $class->condition_sql_option_age_from('age', $opt{'time'} );

  "cust_bill._date <= $age";
}

sub order_sql {
  shift->condition_sql_option_age('age');
}

sub order_sql_weight {
  0;
}

1;
