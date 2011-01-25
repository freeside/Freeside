package FS::TicketSystem;

use strict;
use vars qw( $conf $system $AUTOLOAD );
use FS::Conf;
use FS::UID qw( dbh driver_name );

FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
  $system = $conf->config('ticket_system');
} );

sub AUTOLOAD {
  my $self = shift;

  my($sub)=$AUTOLOAD;
  $sub =~ s/.*://;

  my $conf = new FS::Conf;
  die "FS::TicketSystem::$AUTOLOAD called, but no ticket system configured\n"
    unless $system;

  eval "use FS::TicketSystem::$system;";
  die $@ if $@;

  $self .= "::$system";
  $self->$sub(@_);
}

sub _upgrade_data {
  return if $system ne 'RT_Internal';
  my ($class, %opts) = @_;

  # go ahead and use the RT API for this
  
  FS::TicketSystem->init;
  my $session = FS::TicketSystem->session();
  my $CurrentUser = $session->{'CurrentUser'}
    or die 'freeside-upgrade must run as a valid RT user';

  # CustomFieldChange scrip condition
  my $ScripCondition = RT::ScripCondition->new($CurrentUser);
  $ScripCondition->LoadByCols('ExecModule' => 'CustomFieldChange');
  if (!defined($ScripCondition->Id)) {
    my ($val, $msg) = $ScripCondition->Create(
      'Name' => 'On Custom Field Change',
      'Description' => 'When a custom field is changed to some value',
      'ExecModule' => 'CustomFieldChange',
      'ApplicableTransTypes' => 'Any',
    );
    die $msg if !$val;
  }

  # SetPriority scrip action
  my $ScripAction = RT::ScripAction->new($CurrentUser);
  $ScripAction->LoadByCols('ExecModule' => 'SetPriority');
  if (!defined($ScripAction->Id)) {
    my ($val, $msg) = $ScripAction->Create(
      'Name' => 'Set Priority',
      'Description' => 'Set ticket priority',
      'ExecModule' => 'SetPriority',
      'Argument' => '',
    );
    die $msg if !$val;
  }

  # EscalateQueue custom field and friends
  my $CF = RT::CustomField->new($CurrentUser);
  $CF->Load('EscalateQueue');
  if (!defined($CF->Id)) {
    my ($val, $msg) = $CF->Create(
      'Name' => 'EscalateQueue',
      'Type' => 'Select',
      'MaxValues' => 1,
      'LookupType' => 'RT::Queue',
      'Description' => 'Escalate to Queue',
      'ValuesClass' => 'RT::CustomFieldValues::Queues', #magic!
    );
    die $msg if !$val;
    my $OCF = RT::ObjectCustomField->new($CurrentUser);
    ($val, $msg) = $OCF->Create(
      'CustomField' => $CF->Id,
      'ObjectId' => 0,
    );
    die $msg if !$val;
  }
  return;
}

1;
