package FS::part_event::Condition::billday;

use strict;
use Tie::IxHash;

use base qw( FS::part_event::Condition );

sub description {
  "Customer's monthly billing day is before or on current day or customer has no billing day";
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

  my $delay = $self->option('delay') || 0;
  my $as_of = $opt{'time'} - $delay * 86400; # $opt{'time'}, not time()

  my ($mday) = (localtime($as_of))[3]; # what day it was $delay days before now
  
  (!$cust_main->billday) || ($mday >= $cust_main->billday);
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;
  # ick
  my $delay = $class->condition_sql_option_integer('delay', 
    $opt{'driver_name'}); # returns 0 for null
  my $as_of = $opt{'time'} . " - ($delay * 86400)"; # in seconds
  my $mday;
  if ( $opt{'driver_name'} eq 'Pg' ) {
    $mday = "EXTRACT( DAY FROM TO_TIMESTAMP($as_of) )";
  }
  elsif ( $opt{'driver_name'} eq 'mysql' ) {
    $mday = "DAY( FROM_UNIXTIME($as_of) )";
  }
  else { 
    return 'true'
  }
  
  "cust_main.billday is null or $mday >= cust_main.billday";
}

1;
