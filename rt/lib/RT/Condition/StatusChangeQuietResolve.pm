package RT::Condition::StatusChangeQuietResolve;
use base 'RT::Condition';
use strict;
use warnings;

=head2 DESCRIPTION

This condition allows for muting of resolution notifications when
combined with the ticket status 'resolved_quiet'

If status has been updated as 'resolved_quiet', this condition
will block notification, and update ticket status to 'resolved'

If status has been updated as 'resolved', this condition
will block notification only if the previous ticket status
had been 'resolved_quiet'

=cut

sub IsApplicable {
  my $self = shift;
  my $txn = $self->TransactionObj;
  my ($type, $field) = ($txn->Type, $txn->Field);

  return 0
    unless $type eq 'Status'
    || ($type eq 'Set' && $field eq 'Status');

  return 0
    unless $txn->NewValue eq 'resolved'
    || $txn->NewValue eq 'resolved_quiet';

  my $ticket = $self->TicketObj;

  if ($txn->NewValue eq 'resolved_quiet') {
    $ticket->SetStatus('resolved');
    return 0;
  }
  elsif ($txn->NewValue eq 'resolved' && $txn->OldValue eq 'resolved_quiet') {
    return 0;
  }

  return 1;
}

RT::Base->_ImportOverlays();

1;
