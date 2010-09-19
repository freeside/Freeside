package FS::part_event::Condition;

use strict;
use base qw( FS::part_event_condition );
use Time::Local qw(timelocal_nocheck);
use FS::UID qw( driver_name );

=head1 NAME

FS::part_event::Condition - Base class for event conditions

=head1 SYNOPSIS

package FS::part_event::Condition::mycondition;

use base FS::part_event::Condition;

=head1 DESCRIPTION

FS::part_event::Condition is a base class for event conditions classes.

=head1 METHODS

These methods are implemented in each condition class.

=over 4

=item description

Condition classes must define a description method.  This method should return
a scalar description of the condition.

=item eventtable_hashref

Condition classes must define an eventtable_hashref method if they can only be
tested against some kinds of tables. This method should return a hash reference
of eventtables (values set true indicate the condition can be tested):

  sub eventtable_hashref {
    { 'cust_main'      => 1,
      'cust_bill'      => 1,
      'cust_pkg'       => 0,
      'cust_pay_batch' => 0,
      'cust_statement' => 0,
    };
  }

=cut

#fallback
sub eventtable_hashref {
    { 'cust_main'      => 1,
      'cust_bill'      => 1,
      'cust_pkg'       => 1,
      'cust_pay_batch' => 1,
      'cust_statement' => 1,
    };
}

=item option_fields

Condition classes may define an option_fields method to indicate that they
accept one or more options.

This method should return a list of option names and option descriptions.
Each option description can be a scalar description, for simple options, or a
hashref with the following values:

=over 4

=item label - Description

=item type - Currently text, money, checkbox, checkbox-multiple, select, select-agent, select-pkg_class, select-part_referral, select-table, fixed, hidden, (others can be implemented as httemplate/elements/tr-TYPE.html mason components).  Defaults to text.

=item options - For checkbox-multiple and select, a list reference of available option values.

=item option_labels - For checkbox-multiple (and select?), a hash reference of availble option values and labels.

=item value - for checkbox, fixed, hidden (also a default for text, money, more?)

=item table - for select-table

=item name_col - for select-table

=item NOTE: See httemplate/elements/select-table.html for a full list of the optinal options for the select-table type

=back

NOTE: A database connection is B<not> yet available when this subroutine is
executed.

Example:

  sub option_fields {
    (
      'field'         => 'description',

      'another_field' => { 'label'=>'Amount', 'type'=>'money', },

      'third_field'   => { 'label'         => 'Types',
                           'type'          => 'checkbox-multiple',
                           'options'       => [ 'h', 's' ],
                           'option_labels' => { 'h' => 'Happy',
                                                's' => 'Sad',
                                              },
    );
  }

=cut

#fallback
sub option_fields {
  ();
}

=item condition CUSTOMER_EVENT_OBJECT

Condition classes must define a condition method.  This method is evaluated
to determine if the condition has been met.  The object which triggered the
event (an FS::cust_main, FS::cust_bill or FS::cust_pkg object) is passed as
the first argument.  Additional arguments are list of key-value pairs.

To retreive option values, call the option method on the desired option, i.e.:

  my( $self, $cust_object, %opts ) = @_;
  $value_of_field = $self->option('field');

Available additional arguments:

  $time = $opt{'time'}; #use this instead of time or $^T

  $cust_event = $opt{'cust_event'}; #to retreive the cust_event object being tested

Return a true value if the condition has been met, and a false value if it has
not.

=item condition_sql EVENTTABLE

Condition classes may optionally define a condition_sql method.  This B<class>
method should return an SQL fragment that tests for this condition.  The
fragment is evaluated and a true value of this expression indicates that the
condition has been met.  The event table (cust_main, cust_bill or cust_pkg) is
passed as an argument.

This method is used for optimizing event queries.  You may want to add indices
for any columns referenced.  It is acceptable to return an SQL fragment which
partially tests the condition; doing so will still reduce the number of
records which much be returned and tested with the B<condition> method.

=cut

# fallback.
sub condition_sql {
  my( $class, $eventtable ) = @_;
  #...
  'true';
}

=item disabled

Condition classes may optionally define a disabled method.  Returning a true
value disbles the condition entirely.

=cut

sub disabled {
  0;
}

=item implicit_flag

This is used internally by the I<once> and I<balance> conditions.  You probably
do B<not> want to define this method for new custom conditions, unless you're
sure you want B<every> new action to start with your condition.

Condition classes may define an implicit_flag method that returns true to
indicate that all new events should start with this condition.  (Currently,
condition classes which do so should be applicable to all kinds of
I<eventtable>s.)  The numeric value of the flag also defines the ordering of
implicit conditions.

=cut

#fallback
sub implicit_flag { 0; }

=item remove_warning

Again, used internally by the I<once> and I<balance> conditions; probably not
a good idea for new custom conditions.

Condition classes may define a remove_warning method containing a string
warning message to enable a confirmation dialog triggered when the condition
is removed from an event.

=cut

#fallback
sub remove_warning { ''; }

=item order_sql

This is used internally by the I<balance_age> and I<cust_bill_age> conditions
to declare ordering; probably not of general use for new custom conditions.

=item order_sql_weight

In conjunction with order_sql, this defines which order the ordering fragments
supplied by different B<order_sql> should be used.

=cut

sub order_sql_weight { ''; }

=back

=head1 BASE METHODS

These methods are defined in the base class for use in condition classes.

=over 4 

=item cust_main CUST_OBJECT

Return the customer object (see L<FS::cust_main>) associated with the provided
object (the object itself if it is already a customer object).

=cut

sub cust_main {
  my( $self, $cust_object ) = @_;

  $cust_object->isa('FS::cust_main') ? $cust_object : $cust_object->cust_main;

}

=item option_label OPTIONNAME

Returns the label for the specified option name.

=cut

sub option_label {
  my( $self, $optionname ) = @_;

  my %option_fields = $self->option_fields;

  ref( $option_fields{$optionname} )
    ? $option_fields{$optionname}->{'label'}
    : $option_fields{$optionname}
  or $optionname;
}

=back

=item option_age_from OPTION FROM_TIMESTAMP

Retreives a condition option, parses it from a frequency (such as "1d", "1w" or
"12m"), and subtracts that interval from the supplied timestamp.  It is
primarily intended for use in B<condition>.

=cut

sub option_age_from {
  my( $self, $option, $time ) = @_;
  my $age = $self->option($option);
  $age = '0m' unless length($age);

  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($time) )[0,1,2,3,4,5];

  if ( $age =~ /^(\d+)m$/i ) {
    $mon -= $1;
    until ( $mon >= 0 ) { $mon += 12; $year--; }
  } elsif ( $age =~ /^(\d+)y$/i ) {
    $year -= $1;
  } elsif ( $age =~ /^(\d+)w$/i ) {
    $mday -= $1 * 7;
  } elsif ( $age =~ /^(\d+)d$/i ) {
    $mday -= $1;
  } elsif ( $age =~ /^(\d+)h$/i ) {
    $hour -= $hour;
  } else {
    die "unparsable age: $age";
  }

  timelocal_nocheck($sec,$min,$hour,$mday,$mon,$year);

}

=item condition_sql_option OPTION

This is a class method that returns an SQL fragment for retreiving a condition
option.  It is primarily intended for use in B<condition_sql>.

=cut

sub condition_sql_option {
  my( $class, $option ) = @_;

  ( my $condname = $class ) =~ s/^.*:://;

  "( SELECT optionvalue FROM part_event_condition_option
      WHERE part_event_condition_option.eventconditionnum =
            cond_$condname.eventconditionnum
        AND part_event_condition_option.optionname = '$option'
   )";
}

#c.f. part_event_condition_option.pm / part_event_condition_option_option
#used for part_event/Condition/payby.pm
sub condition_sql_option_option {
  my( $class, $option ) = @_;

  ( my $condname = $class ) =~ s/^.*:://;

  my $optionnum = 
    "( SELECT optionnum FROM part_event_condition_option
        WHERE part_event_condition_option.eventconditionnum =
              cond_$condname.eventconditionnum
          AND part_event_condition_option.optionname  = '$option'
          AND part_event_condition_option.optionvalue = 'HASH'
     )";

  "( SELECT optionname FROM part_event_condition_option_option
       WHERE optionnum = $optionnum
   )";

}


=item condition_sql_option_age_from OPTION FROM_TIMESTAMP

This is a class method that returns an SQL fragment that will retreive a
condition option, parse it from a frequency (such as "1d", "1w" or "12m"),
and subtract that interval from the supplied timestamp.  It is primarily
intended for use in B<condition_sql>.

=cut

sub condition_sql_option_age_from {
  my( $class, $option, $from ) = @_;

  my $value = $class->condition_sql_option($option);

#  my $str2time = str2time_sql;

  if ( driver_name =~ /^Pg/i ) {

    #can we do better with Pg now that we have $from?  yes we can, bob
    "( $from - EXTRACT( EPOCH FROM REPLACE( $value, 'm', 'mon')::interval ) )";

  } elsif ( driver_name =~ /^mysql/i ) {

    #hmm... is there a way we can save $value?  we're just an expression, hmm
    #we might be able to do something like "AS ${option}_value" except we get
    #used in more complicated expressions and we need some sort of unique
    #identifer passed down too... yow

    "CASE WHEN $value IS NULL OR $value = ''
       THEN $from
     WHEN $value LIKE '%m'
       THEN UNIX_TIMESTAMP(
              FROM_UNIXTIME($from) - INTERVAL REPLACE( $value, 'm', '' ) MONTH
            )
     WHEN $value LIKE '%y'
       THEN UNIX_TIMESTAMP(
              FROM_UNIXTIME($from) - INTERVAL REPLACE( $value, 'y', '' ) YEAR
            )
     WHEN $value LIKE '%w'
       THEN UNIX_TIMESTAMP(
              FROM_UNIXTIME($from) - INTERVAL REPLACE( $value, 'w', '' ) WEEK
            )
     WHEN $value LIKE '%d'
       THEN UNIX_TIMESTAMP(
              FROM_UNIXTIME($from) - INTERVAL REPLACE( $value, 'd', '' ) DAY
            )
     WHEN $value LIKE '%h'
       THEN UNIX_TIMESTAMP(
              FROM_UNIXTIME($from) - INTERVAL REPLACE( $value, 'h', '' ) HOUR
            )
     END
    "
  } else {

    die "FATAL: don't know how to subtract frequencies from dates for ".
        driver_name. " databases";

  }

}

=item condition_sql_option_age OPTION

This is a class method that returns an SQL fragment for retreiving a condition
option, and additionaly parsing it from a frequency (such as "1d", "1w" or
"12m") into an approximate number of seconds.

Note that since months vary in length, the results of this method should B<not>
be used in computations (use condition_sql_option_age_from for that).  They are
useful for for ordering and comparison to other ages.

This method is primarily intended for use in B<order_sql>.

=cut

sub condition_sql_option_age {
  my( $class, $option ) = @_;
  $class->age2seconds_sql( $class->condition_sql_option($option) );
}

=item age2seconds_sql

Class method returns an SQL fragment for parsing an arbitrary frequeny (such
as "1d", "1w", "12m", "2y" or "12h") into an approximate number of seconds.

Approximate meaning: months are considered to be 30 days, years to be
365.25 days.  Otherwise the numbers of seconds returned is exact.

=cut

sub age2seconds_sql {
  my( $class, $value ) = @_;

  if ( driver_name =~ /^Pg/i ) {

    "EXTRACT( EPOCH FROM REPLACE( $value, 'm', 'mon')::interval )";

  } elsif ( driver_name =~ /^mysql/i ) {

    #hmm... is there a way we can save $value?  we're just an expression, hmm
    #we might be able to do something like "AS ${option}_age" except we get
    #used in more complicated expressions and we need some sort of unique
    #identifer passed down too... yow
    # 2592000  = 30d "1 month"
    # 31557600 = 365.25d "1 year"

    "CASE WHEN $value IS NULL OR $value = ''
       THEN 0
     WHEN $value LIKE '%m'
       THEN REPLACE( $value, 'm', '' ) * 2592000 
     WHEN $value LIKE '%y'
       THEN REPLACE( $value, 'y', '' ) * 31557600
     WHEN $value LIKE '%w'
       THEN REPLACE( $value, 'w', '' ) * 604800
     WHEN $value LIKE '%d'
       THEN REPLACE( $value, 'd', '' ) * 86400
     WHEN $value LIKE '%h'
       THEN REPLACE( $value, 'h', '' ) * 3600
     END
    "
  } else {

    die "FATAL: don't know how to approximate frequencies for ". driver_name.
        " databases";

  }

}

=head1 NEW CONDITION CLASSES

A module should be added in FS/FS/part_event/Condition/ which implements the
methods desribed above in L</METHODS>.  An example may be found in the
eg/part_event-Condition-template.pm file.

=cut

1;


