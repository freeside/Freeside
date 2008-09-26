package FS::part_bill_event;

use strict;
use vars qw( @ISA $DEBUG @EXPORT_OK );
use Carp qw(cluck confess);
use FS::Record qw( dbh qsearch qsearchs );
use FS::Conf;
use FS::cust_main;
use FS::cust_bill;

@ISA = qw( FS::Record );
@EXPORT_OK = qw( due_events );
$DEBUG = 0;

=head1 NAME

FS::part_bill_event - Object methods for part_bill_event records

=head1 SYNOPSIS

  use FS::part_bill_event;

  $record = new FS::part_bill_event \%hash;
  $record = new FS::part_bill_event { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->do_event( $direct_object );
  
  @events = due_events ( { 'record' => $event_triggering_record,
                           'payby'  => $payby,
			   'event_time => $_date,
			   'extra_sql  => $extra } );

=head1 DESCRIPTION

An FS::part_bill_event object represents a deprecated, old-style invoice event
definition - a callback which is triggered when an invoice is a certain amount
of time overdue.  FS::part_bill_event inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item eventpart - primary key

=item payby - CARD, DCRD, CHEK, DCHK, LECB, BILL, or COMP

=item event - event name

=item eventcode - event action

=item seconds - how long after the invoice date events of this type are triggered

=item weight - ordering for events with identical seconds

=item plan - eventcode plan

=item plandata - additional plan data

=item reason   - an associated reason for this event to fire

=item disabled - Disabled flag, empty or `Y'

=back

=head1 NOTE

Old-style invoice events are only useful for legacy migrations - if you are
looking for current events see L<FS::part_event>.

=head1 METHODS

=over 4

=item new HASHREF

Creates a new invoice event definition.  To add the invoice event definition to
the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_bill_event'; }

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

Checks all fields to make sure this is a valid invoice event definition.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  $self->weight(0) unless $self->weight;

  my $conf = new FS::Conf;
  if ( $conf->exists('safe-part_bill_event') ) {
    my $error = $self->ut_anything('eventcode');
    return $error if $error;

    my $c = $self->eventcode;

    #yay, these regexen will go away with the event refactor

    $c =~ /^\s*\$cust_main\->(suspend|cancel|invoicing_list_addpost|bill|collect)\(\);\s*("";)?\s*$/

      or $c =~ /^\s*\$cust_bill\->(comp|realtime_(card|ach|lec)|batch_card|send)\((%options)*\);\s*$/

      or $c =~ /^\s*\$cust_bill\->send(_if_newest)?\(\'[\w\-\s]+\'\s*(,\s*(\d+|\[\s*\d+(,\s*\d+)*\s*\])\s*,\s*'[\w\@\.\-\+]*'\s*)?\);\s*$/

#      or $c =~ /^\s*\$cust_main\->apply_payments; \$cust_main->apply_credits; "";\s*$/
      or $c =~ /^\s*\$cust_main\->apply_payments_and_credits; "";\s*$/

      or $c =~ /^\s*\$cust_main\->charge\( \s*\d*\.?\d*\s*,\s*\'[\w \!\@\#\$\%\&\(\)\-\+\;\:\"\,\.\?\/]*\'\s*\);\s*$/

      or $c =~ /^\s*\$cust_main\->suspend_(if|unless)_pkgpart\([\d\,\s]*\);\s*$/

      or $c =~ /^\s*\$cust_bill\->cust_suspend_if_balance_over\([\d\.\s]*\);\s*$/

      or do {
        #log
        return "illegal eventcode: $c";
      };

  }

  my $error = $self->ut_numbern('eventpart')
    || $self->ut_enum('payby', [qw( CARD DCLN DCRD CHEK DCHK LECB BILL COMP )] )
    || $self->ut_text('event')
    || $self->ut_anything('eventcode')
    || $self->ut_number('seconds')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    || $self->ut_number('weight')
    || $self->ut_textn('plan')
    || $self->ut_anything('plandata')
    || $self->ut_numbern('reason')
  ;
    #|| $self->ut_snumber('seconds')
  return $error if $error;

  #quelle kludge
  if ( $self->plandata =~ /^(agent_)?templatename\s+(.*)$/m ) {
    my $name= $2;

    foreach my $file (qw( template
                          latex latexnotes latexreturnaddress latexfooter
                            latexsmallfooter
                          html htmlnotes htmlreturnaddress htmlfooter
                     ))
    {
      unless ( $conf->exists("invoice_${file}_$name") ) {
        $conf->set(
          "invoice_${file}_$name" =>
            join("\n", $conf->config("invoice_$file") )
        );
      }
    }
  }

  if ($self->reason){
    my $reasonr = qsearchs('reason', {'reasonnum' => $self->reason});
    return "Unknown reason" unless $reasonr;
  }

  $self->SUPER::check;
}

=item templatename

Returns the alternate invoice template name, if any, or false if there is
no alternate template for this invoice event.

=cut

sub templatename {
  my $self = shift;
  if (    $self->plan     =~ /^send_(alternate|agent)$/
       && $self->plandata =~ /^(agent_)?templatename (.*)$/m
     )
  {
    $2;
  } else {
    '';
  }
}

=item due_events

Returns the list of events due, if any, or false if there is none.
Requires record and payby, but event_time and extra_sql are optional.

=cut

sub due_events {
  my ($record, $payby, $event_time, $extra_sql) = @_;

  #cluck "DEPRECATED: FS::part_bill_event::due_events called on $record";
  confess "DEPRECATED: FS::part_bill_event::due_events called on $record";

  my $interval = 0;
  if ($record->_date){ 
    $event_time = time unless $event_time;
    $interval = $event_time - $record->_date;
  }
  sort {    $a->seconds   <=> $b->seconds
         || $a->weight    <=> $b->weight
	 || $a->eventpart <=> $b->eventpart }
    grep { ref($record) ne 'FS::cust_bill' || $_->eventcode !~ /honor_dundate/
           || $event_time > $record->cust_main->dundate
         }
    grep { $_->seconds <= ( $interval )
           && ! qsearch( 'cust_bill_event', {
	                   'invnum' => $record->get($record->dbdef_table->primary_key),
	                   'eventpart' => $_->eventpart,
	                   'status' => 'done',
			                                                 } )
	 }
      qsearch( {
        'table'     => 'part_bill_event',
	'hashref'   => { 'payby'    => $payby,
	                 'disabled' => '',             },
	'extra_sql' => $extra_sql,
      } );


}

=item do_event

Performs the event and returns any errors that occur.
Requires a record on which to perform the event.
Should only be performed inside a transaction.

=cut

sub do_event {
  my ($self, $object, %options) = @_;

  #cluck "DEPRECATED: FS::part_bill_event::do_event called on $self";
  confess "DEPRECATED: FS::part_bill_event::do_event called on $self";

  warn " calling event (". $self->eventcode. ") for " . $object->table . " " ,
    $object->get($object->dbdef_table->primary_key) . "\n" if $DEBUG > 1;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  #  for "callback" -- heh
  my $cust_main = $object->cust_main;
  my $cust_bill;
  if ($object->table eq 'cust_bill'){
    $cust_bill = $object;
  }
  my $cust_pay_batch;
  if ($object->table eq 'cust_pay_batch'){
    $cust_pay_batch = $object;
  }

  my $error;
  {
    local $SIG{__DIE__}; # don't want Mason __DIE__ handler active
    $error = eval $self->eventcode;
  }

  my $status = '';
  my $statustext = '';
  if ( $@ ) {
    $status = 'failed';
    $statustext = $@;
  } elsif ( $error ) {
    $status = 'done';
    $statustext = $error;
  } else {
    $status = 'done';
  }

  #add cust_bill_event
  my $cust_bill_event = new FS::cust_bill_event {
#    'invnum'     => $object->get($object->dbdef_table->primary_key),
    'invnum'     => $object->invnum,
    'eventpart'  => $self->eventpart,
    '_date'      => time,
    'status'     => $status,
    'statustext' => $statustext,
  };
  $error = $cust_bill_event->insert;
  if ( $error ) {
    my $e = 'WARNING: Event run but database not updated - '.
            'error inserting cust_bill_event, invnum #'.  $object->invnum .
	    ', eventpart '. $self->eventpart.": $error";
    warn $e;
    return $e;
  }
  '';
}

=item reasontext

Returns the text of any reason associated with this event.

=cut

sub reasontext {
  my $self = shift;
  my $r = qsearchs('reason', { 'reasonnum' => $self->reason });
  if ($r){
    $r->reason;
  }else{
    '';
  }
}

=back

=head1 BUGS

The whole "eventcode" idea is bunk.  This should be refactored with subclasses
like part_pkg/ and part_export/

=head1 SEE ALSO

L<FS::cust_bill>, L<FS::cust_bill_event>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

