package FS::Cron::rt_tasks;

use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG $conf );
use Exporter;
use FS::UID qw( dbh driver_name );
use FS::Record qw(qsearch qsearchs);
use FS::TicketSystem;
use FS::Conf;

use Date::Parse qw(str2time);

@ISA = qw( Exporter );
@EXPORT_OK = qw ( rt_daily );
$DEBUG = 0;

FS::UID->install_callback( sub {
  eval "use FS::Conf;";
  die $@ if $@;
  $conf = FS::Conf->new;
});


my %void = ();

sub rt_daily {
  my %opt = @_;
  my @custnums = @ARGV; # ick

  # RT_External installations should have their own cron scripts for this
  my $system = $FS::TicketSystem::system;
  return if $system ne 'RT_Internal';

  # if -d or -y is in use, bail out.  There's no reliable way to tell RT 
  # to use an alternate system time.
  if ( $opt{'d'} or $opt{'y'} ) {
    warn "Forced date options in use - RT daily tasks skipped.\n";
    return;
  }

  FS::TicketSystem->init;
  my $session = FS::TicketSystem->session();
  my $CurrentUser = $session->{'CurrentUser'}
    or die "Failed to create RT session";

  $DEBUG = 1 if $opt{'v'};
  RT::Config->Set( LogToScreen => 'debug' ) if $DEBUG;
 
  # load some modules that aren't handled in FS::TicketSystem 
  foreach (qw(
    Search::ActiveTicketsInQueue
    Action::EscalatePriority
    Action::EscalateQueue
    Action::ScheduledResolve
    )) {
    eval "use RT::$_";
    die $@ if $@;
  }

  # adapted from rt-crontool

  # to make some actions work without complaining
  %void = map { $_ => "RT::$_"->new($CurrentUser) }
    (qw(Scrip ScripAction));

  # compile actions to be run
  my (@actions, @active_tickets);
  my $queues = RT::Queues->new($CurrentUser);
  $queues->UnLimit;
  while (my $queue = $queues->Next) {
    warn "Queue '".$queue->Name."'\n" if $DEBUG;
    my %opt = @_;
    my $tickets = RT::Tickets->new($CurrentUser);
    my $search = RT::Search::ActiveTicketsInQueue->new(
      TicketsObj  => $tickets,
      Argument    => $queue->Id,
      CurrentUser => $CurrentUser,
    );
    $search->Prepare;
    foreach my $custnum ( @custnums ) {
      die "invalid custnum passed to rt_daily: $custnum"
        if !$custnum =~ /^\d+$/;
      $tickets->LimitMemberOf(
        "freeside://freeside/cust_main/$custnum",
        ENTRYAGGREGATOR => 'OR',
        SUBCLAUSE => 'custnum'
      );
    }
    while (my $ticket = $tickets->Next) {
      warn 'Ticket #'.$ticket->Id()."\n" if $DEBUG;
      my @a = task_actions($ticket);
      push @actions, @a;
      push @active_tickets, $ticket if @a; # avoid garbage collection
    }
  }

  # and then commit them all
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

sub task_actions {
  my $ticket = shift;
  (
    ### escalation ###
    $conf->exists('ticket_system-escalation') ? (
      action($ticket, 'EscalatePriority', "CurrentTime: $^T"),
      action($ticket, 'EscalateQueue')
    ) : (),

    ### scheduled resolve ###
    action($ticket, 'ScheduledResolve'),
  );
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
