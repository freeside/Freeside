=head1 NAME

RT::Action::EscalateQueue - move a ticket to a different queue when it reaches its final priority

=head1 DESCRIPTION

EscalateQueue is a ScripAction that will move a ticket to a new 
queue when its priority equals its final priority.  It is designed 
to be used with LinearEscalate or another action that increments
ticket priority on some schedule.  Like those actions, it is intended 
to be called from an escalation tool.

=head1 CONFIGURATION

FinalPriority is a ticket property, defaulting to the queue property.

EscalateQueue is a queue custom field using RT::CustomFieldValues::Queue 
as its data source (that is, it refers to another queue).  Tickets at 
FinalPriority will be moved to that queue.

From a shell you can use the following command:

    rt-crontool --search RT::Search::FromSQL --search-arg \
    "(Status='new' OR Status='open' OR Status = 'stalled')" \
    --action RT::Action::EscalateQueue

No action argument is needed.  Each ticket will be escalated based on the
EscalateQueue property of its current queue.

=cut

package RT::Action::EscalateQueue;

use strict;
use warnings;
use base qw(RT::Action);

our $VERSION = '0.01';

#What does this type of Action does

sub Describe {
    my $self = shift;
    my $class = ref($self) || $self;
    return "$class will move a ticket to its escalation queue when it reaches its final priority."
}

#This Prepare only returns 1 if the ticket will be escalated.

sub Prepare {
    my $self = shift;

    my $ticket = $self->TicketObj;
    my $queue = $ticket->QueueObj;
    my $new_queue = $queue->FirstCustomFieldValue('EscalateQueue');

    my $ticketid = 'Ticket #'.$ticket->Id; #for debug messages
    if ( $ticket->InitialPriority == $ticket->FinalPriority ) {
        $RT::Logger->debug("$ticketid has no priority range.  Not escalating.");
        return 0;
    }

    if ( $ticket->Priority == $ticket->FinalPriority ) {
        if (!$new_queue) {
            $RT::Logger->debug("$ticketid has no escalation queue.  Not escalating.");
            return 0;
        }
        if ($new_queue eq $queue->Name) {
            $RT::Logger->debug("$ticketid would be escalated to its current queue.");
            return 0;
        }
        $self->{'new_queue'} = $new_queue;
        return 1;
    }
    return 0;
}

# whereas Commit returns 1 if it succeeds at whatever it's doing
sub Commit {
    my $self = shift;

    return 1 if !exists($self->{'new_queue'});

    my $ticket = $self->TicketObj;
    my $ticketid = 'Ticket #'.$ticket->Id;
    my $new_queue = RT::Queue->new($ticket->CurrentUser);
    $new_queue->Load($self->{'new_queue'});
    if ( ! $new_queue ) {
        $RT::Logger->debug("Escalation queue ".$self->{'new_queue'}." not found.");
        return 0;
    }
 
    $RT::Logger->debug("Escalating $ticket from ".$ticket->QueueObj->Name .
        ' to '.  $new_queue->Name . ', FinalPriority '.$new_queue->FinalPriority);

    my ( $val, $msg ) = $ticket->SetQueue($self->{'new_queue'});
    if (! $val) {
        $RT::Logger->error( "Couldn't set queue: $msg" );
        return (0, $msg);
    }

    # Set properties of the ticket according to its new queue, so that 
    # escalation Does What You Expect.  Don't record transactions for this;
    # the queue change should be enough.

    ( $val, $msg ) = $ticket->_Set(
      Field => 'FinalPriority',
      Value => $new_queue->FinalPriority,
      RecordTransaction => 0,
    );
    if (! $val) {
        $RT::Logger->error( "Couldn't set new final priority: $msg" );
        return (0, $msg);
    }
    my $Due = new RT::Date( $ticket->CurrentUser );
    if ( my $due_in = $new_queue->DefaultDueIn ) {
        $Due->SetToNow;
        $Due->AddDays( $due_in );
    }
    ( $val, $msg ) = $ticket->_Set(
      Field => 'Due',
      Value => $Due->ISO,
      RecordTransaction => 0,
    );
    if (! $val) {
        $RT::Logger->error( "Couldn't set new due date: $msg" );
        return (0, $msg);
    }
    return 1;
}

1;

=head1 AUTHOR

Mark Wells E<lt>mark@freeside.bizE<gt>

Based on in part LinearEscalate by Kevin Riggle E<lt>kevinr@bestpractical.comE<gt>
and Ruslan Zakirov E<lt>ruz@bestpractical.comE<gt> .

=cut
