package FS::part_event::Condition::once;

use strict;
use FS::Record qw( qsearch );
use FS::part_event;
use FS::cust_event;

use base qw( FS::part_event::Condition );

sub description { "Don't run this event again after it has completed successfully"; }

sub implicit_flag { 10; }

sub remove_warning {
  'Are you sure you want to remove this condition?  Doing so will allow this event to run every time the other conditions are satisfied, even if it has already run sucessfully.'; #better error msg?
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

  ! scalar(@existing);

}

sub condition_sql {
  my( $self, $table ) = @_;

  my %tablenum = %{ FS::part_event->eventtable_pkey_sql };

  "0 = ( SELECT COUNT(*) FROM cust_event
           WHERE cust_event.eventpart = part_event.eventpart
             AND cust_event.tablenum = $tablenum{$table}
             AND status != 'failed'
       )
  ";

}

1;
