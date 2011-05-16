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

1;
