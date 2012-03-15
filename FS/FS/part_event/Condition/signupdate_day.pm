package FS::part_event::Condition::signupdate_day;

use strict;
use Tie::IxHash;

use base qw( FS::part_event::Condition );

sub description {
  "Customer signed up on the same day of month as today";
}

sub option_fields {
  (
    'delay' => { label  => 'Delay additional days',
                 type   => 'text',
                 value  => '0',
               },
  );
}

sub condition {
  my( $self, $object, %opt ) = @_;

  my $cust_main = $self->cust_main($object);

  my ($today) = (localtime($opt{'time'}))[3];

  my $delay = $self->option('delay') || 0;
  my $signupday = ((localtime($cust_main->signupdate + $delay * 86400))[3] - 1)
                   % 28 + 1;
  
  $today == $signupday;
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;
  my $mday;
  if ( $opt{'driver_name'} eq 'Pg' ) {
    $mday = sub{ "EXTRACT( DAY FROM TO_TIMESTAMP($_[0]) )::INTEGER" };
  }
  elsif ( $opt{'driver_name'} eq 'mysql' ) {
    $mday = sub{ "DAY( FROM_UNIXTIME($_[0]) )" };
  }
  else {
    return 'true';
  }

  my $delay = $class->condition_sql_option_integer('delay', 
    $opt{'driver_name'}); # returns 0 for null
  $mday->($opt{'time'}) . ' = '.
    '(' . $mday->("cust_main.signupdate + $delay * 86400") . ' - 1) % 28 + 1';
}

1;
