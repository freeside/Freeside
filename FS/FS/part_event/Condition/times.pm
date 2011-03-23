package FS::part_event::Condition::times;

use strict;
use FS::Record qw( qsearch );
use FS::part_event;
use FS::cust_event;

use base qw( FS::part_event::Condition );

sub description { "Run this event the specified number of times"; }

sub option_fields {
  (
    'run_times'  => { label=>'Interval', type=>'text', value=>'1', },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $obj_pkey = $object->primary_key;
  my $tablenum = $object->$obj_pkey();
 
  my @existing = qsearch( {
    'table'     => 'cust_event',
    'hashref'   => {
                     'eventpart' => $self->eventpart,
                     'tablenum'  => $tablenum,
                     'status'    => { op=>'!=', value=>'failed' },
                   },
    'extra_sql' => ( $opt{'cust_event'}->eventnum =~ /^(\d+)$/
                       ? " AND eventnum != $1 "
                       : ''
                   ),
  } );

  scalar(@existing) <= $self->option('run_times');

}

sub condition_sql {
  my( $class, $table ) = @_;

  my %tablenum = %{ FS::part_event->eventtable_pkey_sql };

  my $existing = "( SELECT COUNT(*) FROM cust_event
                      WHERE cust_event.eventpart = part_event.eventpart
                        AND cust_event.tablenum = $tablenum{$table}
                        AND status != 'failed'
                  )";

  "$existing <= ". $class->condition_sql_option('run_times');

}

1;
