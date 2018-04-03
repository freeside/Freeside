package FS::part_event::Condition::invoice_has_not_been_sent;

use strict;
use FS::Record qw( qsearchs );
use FS::cust_bill;
use Time::Local 'timelocal';

use base qw( FS::part_event::Condition );

sub description {
  'Invoice has not been sent previously';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 0,
    };
}

sub condition {
  my($self, $cust_bill, %opt) = @_;

  my $event = qsearchs( {
    'table'     => 'cust_event',
    'addl_from' => 'LEFT JOIN part_event USING ( eventpart )',
    'hashref'   => {
    		'tablenum'  => $cust_bill->{Hash}->{invnum},
    		'eventtable'  => 'cust_bill',
		'status'    => 'done',
    	},
    'order_by'  => " LIMIT 1",
  } );

  return 0 if $event;

  1;

}

1;