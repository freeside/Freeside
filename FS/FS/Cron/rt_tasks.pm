package FS::Cron::rt_tasks;

use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG );
use Exporter;
use FS::UID qw( dbh driver_name );
use FS::Record qw(qsearch qsearchs);
use FS::TicketSystem;
use FS::Conf;

use Date::Parse qw(str2time);

@ISA = qw( Exporter );
@EXPORT_OK = qw ( rt_escalate );
$DEBUG = 0;

my %void = ();

sub rt_escalate {
  my %opt = @_;
  # RT_External installations should have their own cron scripts for this
  my $system = $FS::TicketSystem::system;
  return if $system ne 'RT_Internal';

  my $conf = new FS::Conf;
  return if !$conf->exists('ticket_system-escalation');

  FS::TicketSystem->init;
  $DEBUG = 1 if $opt{'v'};
  RT::Config->Set( LogToScreen => 'debug' ) if $DEBUG;
  
  #we're at now now (and later).
  my $time = $opt{'d'} ? str2time($opt{'d'}) : $^T;
  $time += $opt{'y'} * 86400 if $opt{'y'};
  my $error = '';

  my $session = FS::TicketSystem->session();
  my $CurrentUser = $session->{'CurrentUser'}
    or die "Failed to create RT session";
 
  # load some modules that aren't handled in FS::TicketSystem 
  foreach (qw(
    Search::ActiveTicketsInQueue 
    Action::EscalatePriority
    Action::EscalateQueue
    )) {
    eval "use RT::$_";
    die $@ if $@;
  }

  # adapted from rt-crontool
  # Mechanics:
  # We're using EscalatePriority, so search in all queues that have a 
  # priority range defined. Select all active tickets in those queues and
  # EscalatePriority, then EscalateQueue them.

  # to make some actions work without complaining
  %void = map { $_ => "RT::$_"->new($CurrentUser) }
    (qw(Scrip ScripAction));

  # Most of this stuff is common to any condition -> action processing 
  # we might want to do, but escalation is the only one we do now.
  my $queues = RT::Queues->new($CurrentUser);
  $queues->UnLimit;
  my @actions = ();
  my @active_tickets = ();
  while (my $queue = $queues->Next) {
    if ( $queue->InitialPriority == $queue->FinalPriority ) {
      warn "Queue '".$queue->Name."' (skipped)\n" if $DEBUG;
      next;
    }
    warn "Queue '".$queue->Name."'\n" if $DEBUG;
    my $tickets = RT::Tickets->new($CurrentUser);
    my $search = RT::Search::ActiveTicketsInQueue->new(
      TicketsObj  => $tickets,
      Argument    => $queue->Name,
      CurrentUser => $CurrentUser,
    );
    $search->Prepare;
    while (my $ticket = $tickets->Next) {
      warn 'Ticket #'.$ticket->Id()."\n" if $DEBUG;
      my @a = (
        action($ticket, 'EscalatePriority', "CurrentTime:$time"),
        action($ticket, 'EscalateQueue')
      );
      next if !@a;
      push @actions, @a;
      push @active_tickets, $ticket; # avoid RT's overzealous garbage collector
    }
  }
  foreach (grep {$_} @actions) {
    my ($val, $msg) = $_->Commit;
    if ( $DEBUG ) {
      if ($val) {
        warn "Action committed: ".ref($_)." #".$_->TicketObj->Id."\n";
      }
      else {
        warn "Action returned $msg: #".$_->TicketObj->Id."\n";
      }
    }
  }
  return;
}

sub action {
  my $ticket = shift;
  my $CurrentUser = $ticket->CurrentUser;

  my $action = shift;
  my $argument = shift;

  $action = "RT::Action::$action";
  my $action_obj = $action->new(
    TicketObj     => $ticket,
    Argument      => $argument,
    Scrip         => $void{'Scrip'},
    ScripAction   => $void{'ScripAction'},
    CurrentUser   => $CurrentUser,
  );
  if ( $action_obj->Prepare ) {
    warn "Action prepared: $action\n" if $DEBUG;
    return $action_obj;
  }
  else {
    return;
  }
}

1;
