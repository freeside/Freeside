package RT::Action::Accumulate;
use base 'RT::Action';

use strict;

=head1 NAME 

RT::Action::Accumulate - Accumulate a running total in a ticket custom field.

This action requires a transaction and ticket custom field with the same name.
When a transaction is submitted with a numeric value in that field, the field 
value for the ticket will be incremented by that amount.  Use this to create 
custom fields that behave like the "TimeWorked" field.

Best used with an "On Update" condition that triggers on any transaction.  The 
ticket custom field update itself does not a create a transaction.

The argument to this action is the name of the custom field.  They must have 
the same name, and should be single-valued fields.

=cut

sub Prepare {
    my $self = shift;
    my $cfname = $self->Argument or return 0;
    $self->{'inc_by'} = $self->TransactionObj->FirstCustomFieldValue($cfname);
    return ( $self->{'inc_by'} =~ /^(\d+)$/ );
}

sub Commit {
    my $self = shift;
    my $cfname = $self->Argument;
    my $newval = $self->{'inc_by'} + 
      ($self->TicketObj->FirstCustomFieldValue($cfname) || 0);
    my ($val) = $self->TicketObj->AddCustomFieldValue(
      Field => 'Support time',
      Value => $newval,
      RecordTransaction => 0,
    );
    return $val;
}

1;

