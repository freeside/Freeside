package FS::part_event::Condition::once_percust;

use strict;
use FS::Record qw( qsearch );
use FS::part_event;
use FS::cust_event;

use base qw( FS::part_event::Condition );

sub description { "Don't run more than once per customer"; }

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 1,
    };
}

sub condition {
  my($self, $object, %opt) = @_;

  my $obj_pkey = $object->primary_key;
  my $obj_table = $object->table;
  my $custnum = $object->custnum;

  my @where = (
    "tablenum IN ( SELECT $obj_pkey FROM $obj_table WHERE custnum = $custnum )"
  );
  if ( $opt{'cust_event'}->eventnum =~ /^(\d+)$/ ) {
    push @where, " eventnum != $1 ";
  }
  my $extra_sql = ' AND '. join(' AND ', @where);
 
  my @existing = qsearch( {
    'table'     => 'cust_event',
    'hashref'   => {
                     'eventpart' => $self->eventpart,
                     #'tablenum'  => $tablenum,
                     'status'    => { op=>'!=', value=>'failed' },
                   },
    'extra_sql' => $extra_sql,
  } );

  ! scalar(@existing);

}

#XXX test?
sub condition_sql {
  my( $self, $table ) = @_;

  my %pkey = %{ FS::part_event->eventtable_pkey };

  my $pkey = $pkey{$table};

  "0 = ( SELECT COUNT(*) FROM cust_event
           WHERE cust_event.eventpart = part_event.eventpart
             AND cust_event.tablenum IN (
               SELECT $pkey FROM $table AS once_percust
                 WHERE once_percust.custnum = cust_main.custnum )
             AND status != 'failed'
       )
  ";

}

1;
