package FS::part_event::Condition::after_event;

use strict;
use FS::Record qw( qsearchs );
use FS::part_event;
use FS::cust_event;

use base qw( FS::part_event::Condition );

sub description { "After running another event" }

# Runs the event at least X days after the most recent time another event
# ran on the same object.

sub option_fields {
  (
    'eventpart' => { label=>'Event', type=>'select-part_event',
                     disable_empty => 1,
                     hashref => { disabled => '' },
                   },
    'run_delay' => { label=>'Delay', type=>'freq', value=>'1',  },
  );
}

# Specification:
# Given an event B that has this condition, where the "eventpart"
# option is set to event A, and the "run_delay" option is set to 
# X days.
# This condition is TRUE if:
# - Event A last ran X or more days in the past,
# AND
# - Event B has not run since the most recent occurrence of event A.

sub condition {
  # similar to "once_every", but with a different eventpart
  my($self, $object, %opt) = @_;

  my $obj_pkey = $object->primary_key;
  my $tablenum = $object->$obj_pkey();

  my $before = $self->option_age_from('run_delay',$opt{'time'});
  my $eventpart = $self->option('eventpart');

  my %hash = (
    'eventpart' => $eventpart,
    'tablenum'  => $tablenum,
    'status'    => { op => '!=', value => 'failed' },
  );

  my $most_recent_other = qsearchs( {
    'table'     => 'cust_event',
    'hashref'   => \%hash,
    'order_by'  => " ORDER BY _date DESC LIMIT 1",
  } )
    or return 0; # if it hasn't run at all, return false
  
  return 0 if $most_recent_other->_date > $before; # we're still in the delay

  # now see if there's been an instance of this event since the one we're
  # following...
  $hash{'eventpart'} = $self->eventpart;
  if ( $opt{'cust_event'} and $opt{'cust_event'}->eventnum =~ /^(\d+)$/ ) {
    $hash{'eventnum'} = { op => '!=', value => $1 };
  }

  my $most_recent_self = qsearchs( {
    'table'     => 'cust_event',
    'hashref'   => \%hash,
    'order_by'  => " ORDER BY _date DESC LIMIT 1",
  } );

  return 0 if defined($most_recent_self) 
          and $most_recent_self->_date >= $most_recent_other->_date;
  # the follower has already run
  
  1;
}

# condition_sql, maybe someday

1;
