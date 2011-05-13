package RT::Condition::CustomFieldTransaction;
use base 'RT::Condition';
use strict;

=head1 NAME

RT::Condition::CustomFieldTransaction

=head1 DESCRIPTION

Returns true if a transaction changed the value of a custom field.  Unlike 
CustomFieldChange, this condition doesn't care what the value was, only that 
it changed.

=head2 Parameters

=over 4

=item field (string)

Only return true if the transaction changed a custom field with this name.  
If empty, returns true for any CustomField-type transaction.

=item include_create (boolean) - Also return true for Create-type transactions.
If 'field' is specified, return true if that field is non-empty in the newly 
created object.

=back

=head2 IsApplicable

If the transaction has changed the value of a custom field.

=head1 BUGS

Probably interacts badly with multiple custom fields with the same name.

=cut

sub IsApplicable {
    my $self = shift;
    my $trans = $self->TransactionObj;
    my $scrip = $self->ScripObj;
    my %Rules = $self->Rules;
    my ($field, $include_create) = @Rules{'field', 'include_create'};

    if ( $include_create and $trans->Type eq 'Create' ) {
        return 1 if !defined($field);
        return 1 if defined($trans->TicketObj->FirstCustomFieldValue($field));
    }
    if ($trans->Type eq 'CustomField') {
        return 1 if !defined($field);
        my $cf = RT::CustomField->new($self->CurrentUser);
        $cf->Load($field);
        return 1 if defined($cf->Id) and $trans->Field == $cf->Id;
    }
    return undef;
}

sub Options {
  my $self = shift;
  my %args = ( 'QueueObj' => undef, @_ );
  my $cfs = RT::CustomFields->new($self->CurrentUser);
  # Allow any ticket custom field to be selected; if it doesn't apply to the 
  # ticket, it will never contain a value and that's fine.
  $cfs->LimitToLookupType('RT::Queue-RT::Ticket');
  my @fieldnames = ('', '(any field)');
  while ( my $cf = $cfs->Next ) {
    push @fieldnames, $cf->Name, $cf->Name;
  }
  return (
    { 
      'name'    => 'field',
      'label'   => 'Custom Field',
      'type'    => 'select',
      'options' => \@fieldnames,
    },
    {
      'name'    => 'include_create',
      'label'   => 'Trigger on ticket creation',
      'type'    => 'checkbox',
    },
  );
}
1;

