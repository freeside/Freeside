package FS::part_event_condition;

use strict;
use vars qw( @ISA $DEBUG @SKIP_CONDITION_SQL );
use FS::UID qw( dbh driver_name );
use FS::Record qw( qsearch qsearchs );
use FS::option_Common;
use FS::part_event; #for order_conditions_sql...

@ISA = qw( FS::option_Common ); # FS::Record );
$DEBUG = 0;

@SKIP_CONDITION_SQL = ();

=head1 NAME

FS::part_event_condition - Object methods for part_event_condition records

=head1 SYNOPSIS

  use FS::part_event_condition;

  $record = new FS::part_event_condition \%hash;
  $record = new FS::part_event_condition { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_event_condition object represents an event condition.
FS::part_event_condition inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item eventconditionnum - primary key

=item eventpart - Event definition (see L<FS::part_event>)

=item conditionname - Condition name - defines which FS::part_event::Condition::I<conditionname> evaluates this condition

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new event.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_event_condition'; }

=item insert [ HASHREF | OPTION => VALUE ... ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If a list or hash reference of options is supplied, part_event_condition_option
records are created (see L<FS::part_event_condition_option>).

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD [ HASHREF | OPTION => VALUE ... ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If a list or hash reference of options is supplied, part_event_condition_option
records are created or modified (see L<FS::part_event_condition_option>).

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('eventconditionnum')
    || $self->ut_foreign_key('eventpart', 'part_event', 'eventpart')
    || $self->ut_alpha('conditionname')
  ;
  return $error if $error;

  #XXX check conditionname to make sure a module exists?
  # well it'll die in _rebless...

  $self->SUPER::check;
}


=item _rebless

Reblesses the object into the FS::part_event::Condition::CONDITIONNAME class,
where CONDITIONNAME is the object's I<conditionname> field.

=cut

sub _rebless {
  my $self = shift;
  my $conditionname = $self->conditionname;
  #my $class = ref($self). "::$conditionname";
  my $class = "FS::part_event::Condition::$conditionname";
  eval "use $class";
  die $@ if $@;
  bless($self, $class); #unless $@;
  $self;
}

=back

=head1 CLASS METHODS

=over 4

=item conditions [ EVENTTABLE ]

Return information about the available conditions.  If an eventtable is
specified, only return information about conditions available for that
eventtable.

Information is returned as key-value pairs.  Keys are condition names.  Values
are hashrefs with the following keys:

=over 4

=item description

=item option_fields

# =item default_weight

# =item deprecated

=back

See L<FS::part_event::Condition> for more information.

=cut

#false laziness w/part_event.pm
#some false laziness w/part_export & part_pkg
my %conditions;
foreach my $INC ( @INC ) {
  foreach my $file ( glob("$INC/FS/part_event/Condition/*.pm") ) {
    warn "attempting to load Condition from $file\n" if $DEBUG;
    $file =~ /\/(\w+)\.pm$/ or do {
      warn "unrecognized file in $INC/FS/part_event/Condition/: $file\n";
      next;
    };
    my $mod = $1;
    my $fullmod = "FS::part_event::Condition::$mod";
    eval "use $fullmod;";
    if ( $@ ) {
      die "error using $fullmod (skipping): $@\n" if $@;
      #warn "error using $fullmod (skipping): $@\n" if $@;
      #next;
    }
    if ( $fullmod->disabled ) {
      warn "$fullmod is disabled; skipping\n";
      next;
    }
    #my $full_condition_sql = $fullmod. '::condition_sql';
    my $condition_sql_coderef = sub { $fullmod->condition_sql(@_) };
    my $order_sql_coderef = $fullmod->can('order_sql')
                              ? sub { $fullmod->order_sql(@_) }
                              : '';
    $conditions{$mod} = {
      ( map { $_ => $fullmod->$_() }
            qw( description eventtable_hashref
                implicit_flag remove_warning
                order_sql_weight
              )
            # deprecated
            #option_fields_hashref
      ),
      'option_fields' => [ $fullmod->option_fields() ],
      'condition_sql' => $condition_sql_coderef,
      'order_sql'     => $order_sql_coderef,
    };
  }
}

sub conditions {
  my( $class, $eventtable ) = @_;
  (
    map  { $_ => $conditions{$_} }
#    sort { $conditions{$a}->{'default_weight'}<=>$conditions{$b}->{'default_weight'} }
#    sort by ?
    $class->all_conditionnames( $eventtable )
  );

}

=item all_conditionnames [ EVENTTABLE ]

Returns a list of just the condition names 

=cut

sub all_conditionnames {
  my ( $class, $eventtable ) = @_;

  grep { !$eventtable || $conditions{$_}->{'eventtable_hashref'}{$eventtable} }
       keys %conditions
}

=item join_conditions_sql [ EVENTTABLE ]

Returns an SQL fragment selecting joining all condition options for an event as
tables titled "cond_I<conditionname>".  Typically used in conjunction with
B<where_conditions_sql>.

=cut

sub join_conditions_sql {
  my ( $class, $eventtable ) = @_;
  my %conditions = $class->conditions( $eventtable );

  join(' ',
    map {
          "LEFT JOIN part_event_condition AS cond_$_".
          "  ON ( part_event.eventpart = cond_$_.eventpart".
          "       AND cond_$_.conditionname = ". dbh->quote($_).
          "     )";
        }
        keys %conditions
  );

}

=item where_conditions_sql [ EVENTTABLE [ , OPTION => VALUE, ... ] ]

Returns an SQL fragment to select events which have unsatisfied conditions.
Must be used in conjunction with B<join_conditions_sql>.

The only current option is "time", the current time (or "pretend" current time
as passed to freeside-daily), as a UNIX timestamp.

=cut

sub where_conditions_sql {
  my ( $class, $eventtable, %options ) = @_;

  my $time = $options{'time'};

  my %conditions = $class->conditions( $eventtable );

  my $where = join(' AND ',
    map {
          my $conditionname = $_;
          my $coderef = $conditions{$conditionname}->{condition_sql};
          my $sql = &$coderef( $eventtable, 'time'        => $time,
                                            'driver_name' => driver_name(),
                             );
          die "$coderef is not a CODEREF" unless ref($coderef) eq 'CODE';
          "( cond_$conditionname.conditionname IS NULL OR $sql )";
        }
        grep { my $cond = $_;
               ! grep { $_ eq $cond } @SKIP_CONDITION_SQL
             }
             keys %conditions
  );

  $where;
}

=item order_conditions_sql [ EVENTTABLE ]

Returns an SQL fragment to order selected events.  Must be used in conjunction
with B<join_conditions_sql>.

=cut

sub order_conditions_sql {
  my( $class, $eventtable ) = @_;

  my %conditions = $class->conditions( $eventtable );

  my $eventtables = join(' ', FS::part_event->eventtables_runorder);

  my $order_by = join(', ',
    "position( part_event.eventtable in ' $eventtables ')",
    ( map  {
             my $conditionname = $_;
             my $coderef = $conditions{$conditionname}->{order_sql};
             my $sql = &$coderef( $eventtable );
             "CASE WHEN cond_$conditionname.conditionname IS NULL
                 THEN -1
                 ELSE $sql
              END
             ";
           }
      sort {     $conditions{$a}->{order_sql_weight}
             <=> $conditions{$b}->{order_sql_weight}
           }
      grep { $conditions{$_}->{order_sql} }
           keys %conditions
    ),
    'part_event.weight'
  );

  "ORDER BY $order_by";

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::part_event::Condition>, L<FS::part_event>, L<FS::Record>, schema.html from
the base documentation.

=cut

1;

