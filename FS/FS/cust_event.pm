package FS::cust_event;

use strict;
use vars qw( @ISA $DEBUG );
use Carp qw( croak confess );
use FS::Record qw( qsearch qsearchs dbdef );
use FS::cust_main_Mixin;
use FS::part_event;
#for cust_X
use FS::cust_main;
use FS::cust_pkg;
use FS::cust_bill;

@ISA = qw(FS::cust_main_Mixin FS::Record);

$DEBUG = 0;

=head1 NAME

FS::cust_event - Object methods for cust_event records

=head1 SYNOPSIS

  use FS::cust_event;

  $record = new FS::cust_event \%hash;
  $record = new FS::cust_event { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_event object represents an completed event.  FS::cust_event
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item eventnum - primary key

=item eventpart - event definition (see L<FS::part_event>)

=item tablenum - customer, package or invoice, depending on the value of part_event.eventtable (see L<FS::cust_main>, L<FS::cust_pkg>, and L<FS::cust_bill>)

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item status - event status: B<new>, B<locked>, B<done> or B<failed>.  Note: B<done> indicates the event is complete and should not be retried (statustext may still be set to an optional message), while B<failed> indicates the event failed and should be retried.

=item statustext - additional status detail (i.e. error or progress message)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new completed invoice event.  To add the compelted invoice event to
the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_event'; }

sub cust_linked { $_[0]->cust_main_custnum; } 
sub cust_unlinked_msg {
  my $self = shift;
  "WARNING: can't find cust_main.custnum ". $self->custnum;
  #' (cust_bill.invnum '. $self->invnum. ')';
}
sub custnum {
  my $self = shift;
  $self->cust_main_custnum(@_) || $self->SUPER::custnum(@_);
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid completed invoice event.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = $self->ut_numbern('eventnum')
    || $self->ut_foreign_key('eventpart', 'part_event', 'eventpart')
  ;
  return $error if $error;

  my $eventtable = $self->part_event->eventtable;
  my $dbdef_eventtable = dbdef->table( $eventtable );

  $error = 
       $self->ut_foreign_key( 'tablenum',
                              $eventtable,
                              $dbdef_eventtable->primary_key
                            )
    || $self->ut_number('_date')
    || $self->ut_enum('status', [qw( new locked done failed )])
    || $self->ut_anything('statustext')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_event

Returns the event definition (see L<FS::part_event>) for this completed event.

=cut

sub part_event {
  my $self = shift;
  qsearchs( 'part_event', { 'eventpart' => $self->eventpart } );
}

=item cust_X

Returns the customer, package, invoice or batched payment (see
L<FS::cust_main>, L<FS::cust_pkg>, L<FS::cust_bill> or L<FS::cust_pay_batch>)
for this completed invoice event.

=cut

sub cust_bill {
  croak "FS::cust_event::cust_bill called";
}

sub cust_X {
  my $self = shift;
  my $eventtable = $self->part_event->eventtable;
  my $dbdef_table = dbdef->table( $eventtable );
  my $primary_key = $dbdef_table->primary_key;
  qsearchs( $eventtable, { $primary_key => $self->tablenum } );
}

=item test_conditions [ OPTION => VALUE ... ]

Tests conditions for this event, returns true if all conditions are satisfied,
false otherwise.

=cut

sub test_conditions {
  my( $self, %opt ) = @_;
  my $part_event = $self->part_event;
  my $object = $self->cust_X;
  my @conditions = $part_event->part_event_condition;
  $opt{'cust_event'} = $self;

  #no unsatisfied conditions
  #! grep ! $_->condition( $object, %opt ), @conditions;
  my @unsatisfied = grep ! $_->condition( $object, %opt ), @conditions;

  if ( $opt{'stats_hashref'} ) {
    foreach my $unsat (@unsatisfied) {
      $opt{'stats_hashref'}->{$unsat->conditionname}++;
    }
  } 

  ! @unsatisfied;
}

=item do_event

Runs the event action.

=cut

sub do_event {
  my $self = shift;

  my $part_event = $self->part_event;

  my $object = $self->cust_X;
  my $obj_pkey = $object->primary_key;
  my $for = "for ". $object->table. " ". $object->$obj_pkey();
  warn "running cust_event ". $self->eventnum.
       " (". $part_event->action. ") $for\n"
    if $DEBUG;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  my $error;
  {
    local $SIG{__DIE__}; # don't want Mason __DIE__ handler active
    $error = eval { $part_event->do_action($object); };
  }

  my $status = '';
  my $statustext = '';
  if ( $@ ) {
    $status = 'failed';
    #$statustext = $@;
    $statustext = "Error running ". $part_event->action. " action: $@";
  } elsif ( $error ) {
    $status = 'done';
    $statustext = $error;
  } else {
    $status = 'done';
  }

  #replace or add myself
  $self->_date(time);
  $self->status($status);
  $self->statustext($statustext);

  $error = $self->eventnum ? $self->replace : $self->insert;
  if ( $error ) {
    #this is why we need that locked state...
    my $e = 'WARNING: Event run but database not updated - '.
            'error replacing or inserting cust_event '. $self->eventnum.
            " $for: $error\n";
    warn $e;
    return $e;
  }

  '';

}

=item retry

Changes the status of this event from B<done> to B<failed>, allowing it to be
retried.

=cut

sub retry {
  my $self = shift;
  return '' unless $self->status eq 'done';
  my $old = ref($self)->new( { $self->hash } );
  $self->status('failed');
  $self->replace($old);
}

#=item retryable
#
#Changes the statustext of this event to B<retriable>, rendering it 
#retriable (should retry be called).
#
#=cut

sub retriable {
  confess "cust_event->retriable called";
  my $self = shift;
  return '' unless $self->status eq 'done';
  my $old = ref($self)->new( { $self->hash } );
  $self->statustext('retriable');
  $self->replace($old);
}

=back

=head1 SUBROUTINES

=over 4

=item reprint

=cut

sub process_reprint {
  process_re_X('print', @_);
}

=item reemail

=cut

sub process_reemail {
  process_re_X('email', @_);
}

=item refax

=cut

sub process_refax {
  process_re_X('fax', @_);
}

use Storable qw(thaw);
use Data::Dumper;
use MIME::Base64;
sub process_re_X {
  my( $method, $job ) = ( shift, shift );

  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;

  re_X(
    $method,
    $param->{'beginning'},
    $param->{'ending'},
    $param->{'failed'},
    $job,
  );

}

#this needs some updating based on the 1.7 cust_bill_event.pm still, i think
sub re_X {
  my($method, $beginning, $ending, $failed, $job) = @_;

  my $from = 'LEFT JOIN part_event USING ( eventpart )';

              # yuck!  hardcoded *AND* sequential scans!
  my $where = " WHERE action LIKE 'cust_bill_send%'".
              "   AND cust_event._date >= $beginning".
              "   AND cust_event._date <= $ending";
  $where .= " AND statustext != '' AND statustext IS NOT NULL"
    if $failed;

  my @cust_event = qsearch({
    'table'     => 'cust_event',
    'addl_from' => $from,
    'hashref'   => {},
    'extra_sql' => $where,
  });

  my( $num, $last, $min_sec ) = (0, time, 5); #progresbar foo
  foreach my $cust_event ( @cust_event ) {

    $cust_event->cust_X->$method(
      $cust_event->part_event->templatename
      || $cust_event->cust_X->agent_template
    );

    if ( $job ) { #progressbar foo
      $num++;
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $num / scalar(@cust_event) )
        );
        die $error if $error;
        $last = time;
      }
    }

  }

  #this doesn't work, but it would be nice
  #if ( $job ) { #progressbar foo
  #  my $error = $job->update_statustext(
  #    scalar(@cust_event). " invoices re-${method}ed"
  #  );
  #  die $error if $error;
  #}

}

=back

=head1 SEE ALSO

L<FS::part_event>, L<FS::cust_bill>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

