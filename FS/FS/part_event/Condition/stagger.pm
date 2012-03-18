package FS::part_event::Condition::stagger;

use strict;
use FS::Record qw( qsearch );
use FS::part_event;
use FS::cust_event;

use base qw( FS::part_event::Condition );

sub description { "Stagger this event across the month" }; #could be clearer?

sub option_fields {
  # delay? it's supposed to be arbitrary anyway
}

sub condition {
  my($self, $object, %opt) = @_;

  my $obj_pkey = $object->primary_key;
  my $tablenum = $object->$obj_pkey();

  my ($today) = (localtime($opt{'time'}))[3];

  $today - 1 == ($tablenum - 1) % 28;
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;

  my %tablenum = %{ FS::part_event->eventtable_pkey_sql };

  my $today;
  if ( $opt{'driver_name'} eq 'Pg' ) {
    $today = "EXTRACT( DAY FROM TO_TIMESTAMP(".$opt{'time'}.") )::INTEGER";
  }
  elsif ( $opt{'driver_name'} eq 'mysql' ) {
    $today = "DAY( FROM_UNIXTIME(".$opt{'time'}.") )";
  }
  else {
    return 'true';
  }
  "($today - 1) = ($tablenum{$table} - 1) % 28";
}

1;
