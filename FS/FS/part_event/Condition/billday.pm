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
                 value  => '1',
               },
  );
}


sub condition {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  
  my $delay = $self->option('delay');
  $delay = 0 unless length($delay);

  (!$cust_main->billday) || ($mday >= $cust_main->billday + $delay);
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;

  my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  
  my $delay = $class->condition_sql_option_integer('delay', $opt{'driver_name'});
  
  "cust_main.billday is null or $mday >= (cust_main.billday + $delay)";
}

1;
