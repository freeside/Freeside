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
    RT::Logger->info('Accumulate::Prepare called on transaction '.
                       $self->TransactionObj->Id." field $cfname");
    my $TransObj = $self->TransactionObj;
    my $TicketObj = $self->TicketObj;
    if ( $TransObj->Type eq 'Create' and
         !defined($TransObj->FirstCustomFieldValue($cfname)) ) {
        # special case: we're creating a new ticket, and the initial value
        # may have been set on the ticket instead of the transaction, so
        # update the transaction to match
        $self->{'obj'} = $TransObj;
        $self->{'inc_by'} = $TicketObj->FirstCustomFieldValue($cfname);
    } else {
        # the usual case when updating an existing ticket
        $self->{'obj'} = $TicketObj;
        $self->{'inc_by'} = $TransObj->FirstCustomFieldValue($cfname) 
                            || '';
    }
    return ( $self->{'inc_by'} =~ /^(\d+)$/ ); # else it's empty
}

sub Commit {
    my $self = shift;
    my $cfname = $self->Argument;
    my $obj = $self->{'obj'};
    my $newval = $self->{'inc_by'} + 
      ($obj->FirstCustomFieldValue($cfname) || 0);
    RT::Logger->info('Accumulate::Commit called on '.ref($obj).' '.
                       $obj->Id." field $cfname");
    my ($val) = $obj->AddCustomFieldValue(
        Field => $cfname,
        Value => $newval,
        RecordTransaction => 0,
    );
    return $val;
}

1;

