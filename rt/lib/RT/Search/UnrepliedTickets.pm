=head1 NAME

  RT::Search::UnrepliedTickets

=head1 SYNOPSIS

=head1 DESCRIPTION

Find all unresolved tickets owned by the current user where the last
correspondence from a requestor (or ticket creation) is more recent than the
last correspondence from a non-requestor (if there is any).

=head1 METHODS

=cut

package RT::Search::UnrepliedTickets;

use strict;
use warnings;
use base qw(RT::Search);


sub Describe  {
  my $self = shift;
  return ($self->loc("Tickets awaiting a reply"));
}

sub Prepare  {
  my $self = shift;

  my $TicketsObj = $self->TicketsObj;
  # bypass the pre-RT-4.2 TicketRestrictions stuff and just use SearchBuilder

  # if SystemUser does this search (as in QueueSummaryByLifecycle), they
  # should get all tickets regardless of ownership
  if ($TicketsObj->CurrentUser->id != RT->SystemUser->id) {
    $TicketsObj->RT::SearchBuilder::Limit(
      FIELD => 'Owner',
      VALUE => $TicketsObj->CurrentUser->id
    );
  }
  $TicketsObj->RT::SearchBuilder::Limit(
    FIELD => 'Status',
    OPERATOR => '!=',
    VALUE => 'resolved'
  );
  $TicketsObj->RT::SearchBuilder::Limit(
    FIELD => 'Status',
    OPERATOR => '!=',
    VALUE => 'rejected',
  );
  my $txn_alias = $TicketsObj->JoinTransactions;
  $TicketsObj->RT::SearchBuilder::Limit(
    ALIAS => $txn_alias,
    FIELD => 'Created',
    OPERATOR => '>',
    VALUE => 'COALESCE(main.Told,\'1970-01-01\')',
    QUOTEVALUE => 0,
  );
  $TicketsObj->RT::SearchBuilder::Limit(
    ALIAS => $txn_alias,
    FIELD => 'Type',
    OPERATOR => '=',
    VALUE => 'Correspond',
    SUBCLAUSE => 'transactiontype',
    ENTRYAGGREGATOR => 'OR',
  );
  $TicketsObj->RT::SearchBuilder::Limit(
    ALIAS => $txn_alias,
    FIELD => 'Type',
    OPERATOR => '=',
    VALUE => 'Create',
    SUBCLAUSE => 'transactiontype',
    ENTRYAGGREGATOR => 'OR',
  );

  return(1);
}

RT::Base->_ImportOverlays();

1;
