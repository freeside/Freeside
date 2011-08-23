package FS::TicketSystem;

use strict;
use vars qw( $conf $system $AUTOLOAD );
use FS::Conf;
use FS::UID qw( dbh driver_name );
use FS::Record qw( dbdef );

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

# Our schema changes
my %columns = (
  Tickets => {
    WillResolve => { type => 'timestamp', null => 1, default => '', },
  },
  CustomFields => {
    Required => { type => 'integer', default => 0, null => 0 },
  },
);

sub _upgrade_schema {
  my $system = FS::Conf->new->config('ticket_system');
  return if !defined($system) || $system ne 'RT_Internal';
  my ($class, %opts) = @_;

  my $dbh = dbh;
  my @sql;
  my $case = driver_name eq 'mysql' ? sub {@_} : sub {map lc, @_};
  foreach my $tablename (keys %columns) {
    my $table = dbdef->table(&$case($tablename));
    if ( !$table ) {
      warn 
      "$tablename table does not exist.  Your RT installation is incomplete.\n";
      next;
    }
    foreach my $colname (keys %{ $columns{$tablename} }) {
      if ( !$table->column(&$case($colname)) ) {
        my $col = new DBIx::DBSchema::Column {
            table_obj => $table,
            name => &$case($colname),
            %{ $columns{$tablename}->{$colname} }
          };
        $col->table_obj($table);
        push @sql, $col->sql_add_column($dbh);
      }
    } #foreach $colname
  } #foreach $tablename

  return if !@sql;
  warn "Upgrading RT schema:\n";
  foreach my $statement (@sql) {
    warn "$statement\n";
    $dbh->do( $statement )
      or die "Error: ". $dbh->errstr. "\n executing: $statement";
  }
  return;
}

sub _upgrade_data {
  return if !defined($system) || $system ne 'RT_Internal';
  my ($class, %opts) = @_;

  # go ahead and use the RT API for this
  
  FS::TicketSystem->init;
  my $session = FS::TicketSystem->session();
  # bypass RT ACLs--we're going to do lots of things
  my $CurrentUser = $RT::SystemUser;

  # selfservice user
  my $User = RT::User->new($CurrentUser);
  $User->Load('%%%SELFSERVICE_USER%%%');
  if (!defined($User->Id)) {
    my ($val, $msg) = $User->Create(
      'Name' => '%%%SELFSERVICE_USER%%%',
      'Gecos' => '%%%SELFSERVICE_USER%%%',
      'Privileged' => 1,
      # any other fields needed?
    );
    die $msg if !$val;
  }
  my $Principal = $User->PrincipalObj; # can this ever fail?
  my @rights = ( qw(ShowTicket SeeQueue ModifyTicket ReplyToTicket 
                    CreateTicket SeeCustomField) );
  foreach (@rights) {
    next if $Principal->HasRight( 'Right' => $_, Object => $RT::System );
    my ($val, $msg) = $Principal->GrantRight(
      'Right' => $_,
      'Object' => $RT::System,
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

  # Load from RT data file
  our (@Groups, @Users, @ACL, @Queues, @ScripActions, @ScripConditions,
       @Templates, @CustomFields, @Scrips, @Attributes, @Initial, @Final);
  my $datafile = '%%%RT_PATH%%%/etc/initialdata';
  eval { require $datafile };
  if ( $@ ) {
    warn "Couldn't load RT data from '$datafile': $@\n(skipping)\n";
    return;
  }

  # Cache existing ScripCondition, ScripAction, and Template IDs
  my $search = RT::ScripConditions->new($CurrentUser);
  $search->UnLimit;
  my %condition = map { lc($_->Name), $_->Id } @{ $search->ItemsArrayRef };

  $search = RT::ScripActions->new($CurrentUser);
  $search->UnLimit;
  my %action = map { lc($_->Name), $_->Id } @{ $search->ItemsArrayRef };

  $search = RT::Templates->new($CurrentUser);
  $search->UnLimit;
  my %template = map { lc($_->Name), $_->Id } @{ $search->ItemsArrayRef };

  # ScripConditions
  my $ScripCondition = RT::ScripCondition->new($CurrentUser);
  foreach my $sc (@ScripConditions) {
    # $sc: Name, Description, ApplicableTransTypes, ExecModule, Argument
    next if exists( $condition{ lc($sc->{Name}) } );
    my ($val, $msg) = $ScripCondition->Create( %$sc );
    die $msg if !$val;
    $condition{ lc($ScripCondition->Name) } = $ScripCondition->Id;
  }

  # ScripActions
  my $ScripAction = RT::ScripAction->new($CurrentUser);
  foreach my $sa (@ScripActions) {
    # $sa: Name, Description, ExecModule, Argument
    next if exists( $action{ lc($sa->{Name}) } );
    my ($val, $msg) = $ScripAction->Create( %$sa );
    die $msg if !$val;
    $action{ lc($ScripAction->Name) } = $ScripAction->Id;
  }

  # Templates
  my $Template = RT::Template->new($CurrentUser);
  foreach my $t (@Templates) {
    # $t: Queue, Name, Description, Content
    next if exists( $template{ lc($t->{Name}) } );
    my ($val, $msg) = $Template->Create( %$t );
    die $msg if !$val;
    $template{ lc($Template->Name) } = $Template->Id;
  }

  # Scrips
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
