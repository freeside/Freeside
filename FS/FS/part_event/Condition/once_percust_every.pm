package FS::part_event::Condition::once_percust_every;

use strict;
use FS::Record qw( qsearch );
use FS::part_event;
use FS::cust_event;

use base qw( FS::part_event::Condition );

sub description { "Don't run this event more than once per customer in the specified interval"; }

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 1,
      'cust_pkg'  => 1,
    };
}

# Runs the event at most "once every X", per customer.

sub option_fields {
  (
    'run_delay'  => { label=>'Interval', type=>'freq', value=>'1m', },
  );
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
 
  my $max_date = $self->option_age_from('run_delay', $opt{'time'});
 
  my @existing = qsearch( {
    'table'     => 'cust_event',
    'hashref'   => {
                     'eventpart' => $self->eventpart,
                     'status'    => { op=>'!=', value=>'failed'  },
                     '_date'     => { op=>'>',  value=>$max_date },
                   },
    'extra_sql' => $extra_sql,
  } );

  ! scalar(@existing);

}

1;
