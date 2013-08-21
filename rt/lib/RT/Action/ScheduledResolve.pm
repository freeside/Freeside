package RT::Action::ScheduledResolve;

use strict;
use warnings;

use base qw(RT::Action);

=head1 DESCRIPTION

If the ticket's WillResolve date is in the past, set its status to resolved.

=cut

sub Prepare {
    my $self = shift;

    return undef if grep { $self->TicketObj->Status eq $_ } (
      'resolved',
      'rejected',
      'deleted'
    ); # don't resolve from any of these states.
    my $time = $self->TicketObj->WillResolveObj->Unix;
    # resolve if the WillResolve date is set, and in the past,
    # and less than a year old
    return ( $time > 0 and $time < time() and (time() - $time) < 31536000 );
}

sub Commit {
    my $self = shift;

    my $never = RT::Date->new($self->CurrentUser);
    $never->Unix(-1);
    $self->TicketObj->SetWillResolve($never->ISO);
    $self->TicketObj->SetStatus('resolved');
}

RT::Base->_ImportOverlays();

1;
