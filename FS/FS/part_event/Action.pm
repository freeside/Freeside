package FS::part_event::Action;

use strict;
use base qw( FS::part_event );
use Tie::IxHash;

=head1 NAME

FS::part_event::Action - Base class for event actions

=head1 SYNOPSIS

package FS::part_event::Action::myaction;

use base FS::part_event::Action;

=head1 DESCRIPTION

FS::part_event::Action is a base class for event action classes.

=head1 METHODS

These methods are implemented in each action class.

=over 4

=item description

Action classes must define a description method.  This method should return a
scalar description of the action.

=item eventtable_hashref

Action classes must define a eventtable_hashref method if they can only be
triggered against some kinds of tables.  This method should return a hash
reference of eventtables (values set true indicate the action can be performed):

  sub eventtable_hashref {
    { 'cust_main'      => 1,
      'cust_bill'      => 1,
      'cust_pkg'       => 0,
      'cust_pay_batch' => 0,
    };
  }

=cut

#fallback
sub eventtable_hashref {
    { 'cust_main'      => 1,
      'cust_bill'      => 1,
      'cust_pkg'       => 1,
      'cust_pay_batch' => 1,
    };
}

=item option_fields

Action classes may define an option_fields method to indicate that they
accept one or more options.

This method should return a list of option names and option descriptions.
Each option description can be a scalar description, for simple options, or a
hashref with the following values:

=over 4

=item label - Description

=item type - Currently text, money, checkbox, checkbox-multiple, select, select-agent, select-pkg_class, select-part_referral, select-table, fixed, hidden, (others can be implemented as httemplate/elements/tr-TYPE.html mason components).  Defaults to text.

=item size - Size for text fields

=item options - For checkbox-multiple and select, a list reference of available option values.

=item option_labels - For select, a hash reference of availble option values and labels.

=item value - for checkbox, fixed, hidden

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
                           'type'          => 'select',
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

=item default_weight

Action classes may define a default weighting.  Weights control execution order
relative to other actions (that are triggered at the same time).

=cut

#fallback
sub default_weight {
  100;
}

=item deprecated

Action classes may define a deprecated method that returns true, indicating
that this action is deprecated.

=cut

#default
sub deprecated {
  0;
}

=item do_action CUSTOMER_EVENT_OBJECT

Action classes must define an action method.  This method is triggered if
all conditions have been met.

The object which triggered the event (an FS::cust_main, FS::cust_bill or
FS::cust_pkg object) is passed as an argument.

To retreive option values, call the option method on the desired option, i.e.:

  my( $self, $cust_object ) = @_;
  $value_of_field = $self->option('field');

To indicate sucessful completion, simply return.  Optionally, you can return a
string of information status information about the sucessful completion, or
simply return the empty string.

To indicate a failure and that this event should retry, die with the desired
error message.

=back

=head1 BASE METHODS

These methods are defined in the base class for use in action classes.

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

=item option_fields_hashref

Returns the option fields as an (ordered) hash reference.

=cut

sub option_fields_hashref {
  my $self = shift;
  tie my %hash, 'Tie::IxHash', $self->option_fields;
  \%hash;
}

=item option_fields_listref

Returns just the option field names as a list reference.

=cut

sub option_fields_listref {
  my $self = shift;
  my $hashref = $self->option_fields_hashref;
  warn $hashref;
  [ keys %$hashref ];
}

=back

=cut

1;

