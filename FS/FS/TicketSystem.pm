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
  return if !defined($system) || $system ne 'RT_Internal';
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

  # Create any missing scrips
  our (@Groups, @Users, @ACL, @Queues, @ScripActions, @ScripConditions,
       @Templates, @CustomFields, @Scrips, @Attributes, @Initial, @Final);
  my $datafile = '%%%RT_PATH%%%/etc/initialdata';
  eval { require $datafile };
  if ( $@ ) {
    warn "Couldn't load RT data from '$datafile': $@\n(skipping)\n";
    return;
  }

  my $search = RT::ScripConditions->new($CurrentUser);
  $search->UnLimit;
  my %condition = map { lc($_->Name), $_->Id } @{ $search->ItemsArrayRef };

  $search = RT::ScripActions->new($CurrentUser);
  $search->UnLimit;
  my %action = map { lc($_->Name), $_->Id } @{ $search->ItemsArrayRef };

  $search = RT::Templates->new($CurrentUser);
  $search->UnLimit;
  my %template = map { lc($_->Name), $_->Id } @{ $search->ItemsArrayRef };

  my $Scrip = RT::Scrip->new($CurrentUser);
  foreach my $s ( @Scrips ) {
    my $desc = $s->{'Description'};
    my ($c, $a, $t) = map lc,
      @{ $s }{'ScripCondition', 'ScripAction', 'Template'};
    if ( !$condition{$c} ) {
      warn "ScripCondition '$c' not found.\n";
      next;
    }
    if ( !$action{$a} ) {
      warn "ScripAction '$a' not found.\n";
      next;
    }
    if ( !$template{$t} ) {
      warn "Template '$t' not found.\n";
      next;
    }
    my %param = (
      ScripCondition => $condition{$c},
      ScripAction => $action{$a},
      Template => $template{$t},
      Queue => 0,
    );
    $Scrip->LoadByCols(%param);
    if (!defined($Scrip->Id)) {
      my ($val, $msg) = $Scrip->Create(%param, Description => $desc);
      die $msg if !$val;
    }
  } #foreach (@Scrips)

  return;
}

1;
