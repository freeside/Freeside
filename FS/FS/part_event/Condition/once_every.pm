package FS::part_event::Condition::once_every;

use strict;
use FS::Record qw( qsearch );
use FS::part_event;
use FS::cust_event;

use base qw( FS::part_event::Condition );

sub description { "Don't run this event more than once in interval"; }

# Runs the event at most "once every X".

sub option_fields {
  (
    'run_delay'  => { label=>'Interval', type=>'freq', value=>'1m', },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $obj_pkey = $object->primary_key;
  my $tablenum = $object->$obj_pkey();

  my $max_date = $self->option_age_from('run_delay',$opt{'time'});
 
  my @existing = qsearch( {
    'table'     => 'cust_event',
    'hashref'   => {
                     'eventpart' => $self->eventpart,
                     'tablenum'  => $tablenum,
                     'status'    => { op=>'!=', value=>'failed'  },
                     '_date'     => { op=>'>=', value=>$max_date },
                   },
    'extra_sql' => ( $opt{'cust_event'}->eventnum =~ /^(\d+)$/
                       ? " AND eventnum != $1 "
                       : ''
                   ),
  } );

  ! scalar(@existing);

}

1;
