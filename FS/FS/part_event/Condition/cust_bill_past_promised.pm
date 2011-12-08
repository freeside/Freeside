package FS::part_event::Condition::cust_bill_past_promised;

use strict;
use FS::cust_bill;
use Time::Local 'timelocal';

use base qw( FS::part_event::Condition );

sub description {
  'Promised payment date has passed',
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
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
  # always return true if there is no promised_date
  my($self, $cust_bill, %opt) = @_;

  my $delay = $self->option('delay') || 0;
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($opt{'time'}))[0..5];
  my $as_of = timelocal(0,0,0,$mday,$mon,$year) - $delay * 86400;
  $as_of >= ($cust_bill->promised_date || 0);
}

sub condition_sql {
  my( $class, $table, %opt ) = @_;
  return 'true' if $opt{'driver_name'} ne 'Pg';
  my $delay = $class->condition_sql_option_integer('delay', 'Pg');
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($opt{'time'}))[0..5];
  my $as_of = timelocal(0,0,0,$mday,$mon,$year) . " - ($delay * 86400)";
  "(cust_bill.promised_date IS NULL OR $as_of >= cust_bill.promised_date)";
}

1;
