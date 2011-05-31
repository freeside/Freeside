package RT::Ticket;
use strict;

sub SetPriority {
  # Special case: Pass a value starting with 'R' to set priority 
  # relative to the current level.  Used for bulk updates, though 
  # it can be used anywhere else too.
  my $Ticket = shift;
  my $value = shift;
  if ( $value =~ /^R([+-]?\d+)$/ ) {
    $value = $1 + ($Ticket->Priority || 0);
  }
  $Ticket->SUPER::SetPriority($value);
}

=head2 MissingRequiredFields {

Return all custom fields with the Required flag set for which this object
doesn't have any non-empty values.

=cut

sub MissingRequiredFields {
    my $self = shift;
    my $CustomFields = $self->CustomFields;
    my @results;
    while ( my $CF = $CustomFields->Next ) {
        next if !$CF->Required;
        if ( !length($self->FirstCustomFieldValue($CF->Id) || '') )  {
            push @results, $CF;
        }
    }
    return @results;
}

1;
