package FS::part_event::Condition::cust_bill_past_due;

use strict;
use FS::cust_bill;
use Time::Local 'timelocal';

use base qw( FS::part_event::Condition );

sub description {
  'Invoice due date has passed';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

sub condition {
  my($self, $cust_bill, %opt) = @_;

  # If the invoice date is 1/1 at noon and the terms are Net 15,
  # the due_date will be 1/16 at noon.  Past due events will not 
  # trigger until after the start of 1/17.
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($opt{'time'}))[0..5];
  my $start_of_today = timelocal(0,0,0,$mday,$mon,$year)+1;
  ($cust_bill->due_date || $cust_bill->_date) < $start_of_today;
}

sub condition_sql {
  return '' if $FS::UID::driver_name ne 'Pg';
  my( $class, $table, %opt ) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($opt{'time'}))[0..5];
  my $start_of_today = timelocal(0,0,0,$mday,$mon,$year)+1;

  FS::cust_bill->due_date_sql . " < $start_of_today";

}

1;
