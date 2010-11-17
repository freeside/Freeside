package RT::Condition::CustomFieldChange;
use base 'RT::Condition';
use strict;

=head2 IsApplicable

If a custom field has a particular value.

=cut

# Based on Chuck Boeheim's code posted on the RT Wiki 3/13/06

sub IsApplicable {
    my $self = shift;
    my $trans = $self->TransactionObj;
    my $scrip = $self->ScripObj;
    my %Rules = $self->Rules;
    my ($field, $value) = @Rules{'field', 'value'};
    return if !defined($field) or !defined($value);

    if ($trans->Type eq 'Create') {
        return 1 if $trans->TicketObj->FirstCustomFieldValue($field) eq $value;
    }
    if ($trans->Type eq 'CustomField') {
        my $cf = RT::CustomField->new($self->CurrentUser);
        $cf->Load($field);
        return 1 if $trans->Field == $cf->Id and $trans->NewValue eq $value;
    }
    return undef;
}

sub Options {
  my $self = shift;
  my %args = ( 'QueueObj' => undef, @_ );
  my $QueueObj = $args{'QueueObj'};
  my $cfs = $QueueObj->TicketCustomFields();
  my @fieldnames;
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
      'name'    => 'value',
      'label'   => 'Value',
      'type'    => 'text',
    },
  );
}
1;

