package RT::Condition::CustomFieldEquals;
use base 'RT::Condition';
use strict;

=head2 IsApplicable

If a custom field has a value equal to some specified value.

=cut

# Based on Chuck Boeheim's code posted on the RT Wiki 3/13/06
# Simplified to avoid carrying old schema around. The new mechanics are that
# the ScripCondition's "Argument" is the custom field name = value. If the 
# transaction initially sets the CF value to a the specified value, or 
# changes it from not equaling to equaling the specified value, the condition
# returns true.
# Don't use this on custom fields that allow multiple values.

sub IsApplicable {
    my $self = shift;
    my $trans = $self->TransactionObj;
    my $scrip = $self->ScripObj;
    my ($field, $value) = split('=', $self->Argument, 2);

    if ($trans->Type eq 'Create') {
        return ($trans->TicketObj->FirstCustomFieldValue($field) eq $value);
    }
    if ($trans->Type eq 'CustomField') {
        my $cf = RT::CustomField->new($self->CurrentUser);
        $cf->Load($field);
        return (   $trans->Field == $cf->Id
               and $trans->NewValue eq $value
               and $trans->OldValue ne $value
               );
    }
    return undef;
}

1;

