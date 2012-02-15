package FS::part_event;

use strict;
use vars qw( @ISA $DEBUG );
use Carp qw(confess);
use FS::Record qw( dbh qsearch qsearchs );
use FS::option_Common;
use FS::m2name_Common;
use FS::Conf;
use FS::part_event_option;
use FS::part_event_condition;
use FS::cust_event;
use FS::agent;

@ISA = qw( FS::m2name_Common FS::option_Common ); # FS::Record );
$DEBUG = 0;

=head1 NAME

FS::part_event - Object methods for part_event records

=head1 SYNOPSIS

  use FS::part_event;

  $record = new FS::part_event \%hash;
  $record = new FS::part_event { 'column' => 'value' };

  $error = $record->insert( { 'option' => 'value' } );
  $error = $record->insert( \%options );

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->do_event( $direct_object );
  
=head1 DESCRIPTION

An FS::part_event object represents an event definition - a billing, collection
or other callback which is triggered when certain customer, invoice, package or
other conditions are met.  FS::part_event inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item eventpart - primary key

=item agentnum - Optional agentnum (see L<FS::agent>)

=item event - event name

=item eventtable - table name against which this event is triggered; currently "cust_bill" (the traditional invoice events), "cust_main" (customer events) or "cust_pkg (package events) (or "cust_statement")

=item check_freq - how often events of this type are checked; currently "1d" (daily) and "1m" (monthly) are recognized.  Note that the apprioriate freeside-daily and/or freeside-monthly cron job needs to be in place.

=item weight - ordering for events

=item action - event action (like part_bill_event.plan - eventcode plan)

=item disabled - Disabled flag, empty or `Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new invoice event definition.  To add the invoice event definition to
the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_event'; }

=item insert [ HASHREF ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If a list or hash reference of options is supplied, part_export_option records
are created (see L<FS::part_event_option>).

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD [ HASHREF | OPTION => VALUE ... ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If a list or hash reference of options is supplied, part_event_option
records are created or modified (see L<FS::part_event_option>).

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

  my $error = 
       $self->ut_numbern('eventpart')
    || $self->ut_text('event')
    || $self->ut_enum('eventtable', [ $self->eventtables ] )
    || $self->ut_enum('check_freq', [ '1d', '1m' ])
    || $self->ut_number('weight')
    || $self->ut_alpha('action')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    || $self->ut_agentnum_acl('agentnum', 'Edit global billing events')
  ;
  return $error if $error;

  #XXX check action to make sure a module exists?
  # well it'll die in _rebless...

  $self->SUPER::check;
}

=item _rebless

Reblesses the object into the FS::part_event::Action::ACTION class, where
ACTION is the object's I<action> field.

=cut

sub _rebless {
  my $self = shift;
  my $action = $self->action or return $self;
  #my $class = ref($self). "::$action";
  my $class = "FS::part_event::Action::$action";
  eval "use $class";
  die $@ if $@;
  bless($self, $class); # unless $@;
  $self;
}

=item part_event_condition

Returns the conditions associated with this event, as FS::part_event_condition
objects (see L<FS::part_event_condition>)

=cut

sub part_event_condition {
  my $self = shift;
  qsearch( 'part_event_condition', { 'eventpart' => $self->eventpart } );
}

=item new_cust_event OBJECT

Creates a new customer event (see L<FS::cust_event>) for the provided object.

=cut

sub new_cust_event {
  my( $self, $object ) = @_;

  confess "**** $object is not a ". $self->eventtable
    if ref($object) ne "FS::". $self->eventtable;

  my $pkey = $object->primary_key;

  new FS::cust_event {
    'eventpart' => $self->eventpart,
    'tablenum'  => $object->$pkey(),
    '_date'     => time, #i think we always want the real "now" here.
    'status'    => 'new',
  };
}

#surely this doesn't work
sub reasontext { confess "part_event->reasontext deprecated"; }
#=item reasontext
#
#Returns the text of any reason associated with this event.
#
#=cut
#
#sub reasontext {
#  my $self = shift;
#  my $r = qsearchs('reason', { 'reasonnum' => $self->reason });
#  if ($r){
#    $r->reason;
#  }else{
#    '';
#  }
#}

=item agent 

Returns the associated agent for this event, if any, as an FS::agent object.

=cut

sub agent {
  my $self = shift;
  qsearchs('agent', { 'agentnum' => $self->agentnum } );
}

=item templatename

Returns the alternate invoice template name, if any, or false if there is
no alternate template for this event.

=cut

sub templatename {

  my $self = shift;
  if (    $self->action   =~ /^cust_bill_send_(alternate|agent)$/
          && (    $self->option('agent_templatename')
               || $self->option('templatename')       )
     )
  {
       $self->option('agent_templatename')
    || $self->option('templatename');

  } else {
    '';
  }
}

=item targets

Returns all objects (of type C<FS::eventtable>, for this object's 
C<eventtable>) eligible for processing under this event, as of right now.
The L<FS::cust_event> object used to test event conditions will be 
included in each object as the 'cust_event' pseudo-field.

This is not used in normal event processing (which is done on a 
per-customer basis to control timing of pre- and post-billing events)
but can be useful when configuring events.

=cut

sub targets {
  my $self = shift;
  my $time = time; # $opt{'time'}?

  my $eventpart = $self->eventpart;
  $eventpart =~ /^\d+$/ or die "bad eventpart $eventpart";
  my $eventtable = $self->eventtable;

  # find all objects that meet the conditions for this part_event
  my $linkage = '';
  # this is the 'object' side of the FROM clause
  if ( $eventtable ne 'cust_main' ) {
    $linkage = 
        #($self->eventtables_cust_join->{$eventtable} || '') . #2.3
        ' LEFT JOIN cust_main USING (custnum) ';
  }

  # this is the 'event' side
  my $join = FS::part_event_condition->join_conditions_sql( $eventtable );
  my $where = FS::part_event_condition->where_conditions_sql( $eventtable,
    'time' => $time
  );
  $join = $linkage .
      " INNER JOIN part_event ON ( part_event.eventpart = $eventpart ) $join";

  $where .= ' AND cust_main.agentnum = '.$self->agentnum
    if $self->agentnum;
  # don't enforce check_freq since this is a special, out-of-order check
  # and don't enforce disabled because we want to be able to see targets 
  # for a disabled event

  my @objects = qsearch({
      table     => $eventtable,
      hashref   => {},
      addl_from => $join,
      extra_sql => "WHERE $where",
  });
  my @tested_objects;
  foreach my $object ( @objects ) {
    my $cust_event = $self->new_cust_event($object, 'time' => $time);
    next unless $cust_event->test_conditions;

    $object->set('cust_event', $cust_event);
    push @tested_objects, $object;
  }
  @tested_objects;
}

=back

=head1 CLASS METHODS

=over 4

=item eventtable_labels

Returns a hash reference of labels for eventtable values,
i.e. 'cust_main'=>'Customer'

=cut

sub eventtable_labels {
  #my $class = shift;

  tie my %hash, 'Tie::IxHash',
    'cust_pkg'       => 'Package',
    'cust_bill'      => 'Invoice',
    'cust_main'      => 'Customer',
    'cust_pay_batch' => 'Batch payment',
    'cust_statement' => 'Statement',  #too general a name here? "Invoice group"?
  ;

  \%hash
}

=item eventtable_pkey_sql

Returns a hash reference of full SQL primary key names for eventtable values,
i.e. 'cust_main'=>'cust_main.custnum'

=cut

sub eventtable_pkey_sql {
  my $class = shift;

  my $hashref = $class->eventtable_pkey;

  my %hash = map { $_ => "$_.". $hashref->{$_} } keys %$hashref;

  \%hash;
}

=item eventtable_pkey

Returns a hash reference of full SQL primary key names for eventtable values,
i.e. 'cust_main'=>'custnum'

=cut

sub eventtable_pkey {
  #my $class = shift;

  {
    'cust_main'      => 'custnum',
    'cust_bill'      => 'invnum',
    'cust_pkg'       => 'pkgnum',
    'cust_pay_batch' => 'paybatchnum',
    'cust_statement' => 'statementnum',
  };
}

=item eventtables

Returns a list of eventtable values (default ordering; suited for display).

=cut

sub eventtables {
  my $class = shift;
  my $eventtables = $class->eventtable_labels;
  keys %$eventtables;
}

=item eventtables_runorder

Returns a list of eventtable values (run order).

=cut

sub eventtables_runorder {
  shift->eventtables; #same for now
}

=item check_freq_labels

Returns a hash reference of labels for check_freq values,
i.e. '1d'=>'daily'

=cut

sub check_freq_labels {
  #my $class = shift;

  #Tie::IxHash??
  {
    '1d' => 'daily',
    '1m' => 'monthly',
  };
}

=item actions [ EVENTTABLE ]

Return information about the available actions.  If an eventtable is specified,
only return information about actions available for that eventtable.

Information is returned as key-value pairs.  Keys are event names.  Values are
hashrefs with the following keys:

=over 4

=item description

=item eventtable_hashref

=item option_fields

=item default_weight

=item deprecated

=back

See L<FS::part_event::Action> for more information.

=cut

#false laziness w/part_event_condition.pm
#some false laziness w/part_export & part_pkg
my %actions;
foreach my $INC ( @INC ) {
  foreach my $file ( glob("$INC/FS/part_event/Action/*.pm") ) {
    warn "attempting to load Action from $file\n" if $DEBUG;
    $file =~ /\/(\w+)\.pm$/ or do {
      warn "unrecognized file in $INC/FS/part_event/Action/: $file\n";
      next;
    };
    my $mod = $1;
    eval "use FS::part_event::Action::$mod;";
    if ( $@ ) {
      die "error using FS::part_event::Action::$mod (skipping): $@\n" if $@;
      #warn "error using FS::part_event::Action::$mod (skipping): $@\n" if $@;
      #next;
    }
    $actions{$mod} = {
      ( map { $_ => "FS::part_event::Action::$mod"->$_() }
            qw( description eventtable_hashref default_weight deprecated )
            #option_fields_hashref
      ),
      'option_fields' => [ "FS::part_event::Action::$mod"->option_fields() ],
    };
  }
}

sub actions {
  my( $class, $eventtable ) = @_;
  (
    map  { $_ => $actions{$_} }
    sort { $actions{$a}->{'default_weight'}<=>$actions{$b}->{'default_weight'} }
    $class->all_actions( $eventtable )
  );

}

=item all_actions [ EVENTTABLE ]

Returns a list of just the action names

=cut

sub all_actions {
  my ( $class, $eventtable ) = @_;

  grep { !$eventtable || $actions{$_}->{'eventtable_hashref'}{$eventtable} }
       keys %actions
}

=back

=head1 SEE ALSO

L<FS::part_event_option>, L<FS::part_event_condition>, L<FS::cust_main>,
L<FS::cust_pkg>, L<FS::cust_bill>, L<FS::cust_bill_event>, L<FS::Record>,
schema.html from the base documentation.

=cut

1;

