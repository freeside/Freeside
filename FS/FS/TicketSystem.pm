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
        my ($alter, $postalter) = $col->sql_add_column($dbh);
        foreach (@$alter) {
          push @sql, "ALTER TABLE $tablename $_;";
        }
        push @sql, @$postalter;
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

  my $dbh = dbh;

  # selfservice and cron users
  foreach my $username ('%%%SELFSERVICE_USER%%%', 'fs_daily') {
    my $User = RT::User->new($CurrentUser);
    $User->Load($username);
    if (!defined($User->Id)) {
      my ($val, $msg) = $User->Create(
        'Name' => $username,
        'Gecos' => $username,
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
  } #foreach $username

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
       @Templates, @CustomFields, @Scrips, @Attributes, @Initial, @Final,
       %Delete_Scrips);
  my $datafile = '%%%RT_PATH%%%/etc/initialdata';
  eval { require $datafile };
  if ( $@ ) {
    warn "Couldn't load RT data from '$datafile': $@\n(skipping)\n";
    return;
  }

  # Cache existing ScripCondition, ScripAction, and Template IDs.
  # Complicated because we don't want to just step on multiple IDs 
  # with the same name.
  my $cachify = sub {
    my ($class, $hash) = @_;
    my $search = $class->new($CurrentUser);
    $search->UnLimit;
    while ( my $item = $search->Next ) {
      my $ids = $hash->{lc($item->Name)} ||= [];
      if ( $item->Creator == 1 ) { # RT::SystemUser
        unshift @$ids, $item->Id;
      }
      else {
        push @$ids, $item->Id;
      }
    }
  };

  my (%condition, %action, %template);
  &$cachify('RT::ScripConditions', \%condition);
  &$cachify('RT::ScripActions', \%action);
  &$cachify('RT::Templates', \%template);
  # $condition{name} = [ ids... ]
  # with the id of the system-created object first, if there is one

  # ScripConditions
  my $ScripCondition = RT::ScripCondition->new($CurrentUser);
  foreach my $sc (@ScripConditions) {
    # $sc: Name, Description, ApplicableTransTypes, ExecModule, Argument
    next if exists( $condition{ lc($sc->{Name}) } );
    my ($val, $msg) = $ScripCondition->Create( %$sc );
    die $msg if !$val;
    $condition{ lc($ScripCondition->Name) } = [ $ScripCondition->Id ];
  }

  # ScripActions
  my $ScripAction = RT::ScripAction->new($CurrentUser);
  foreach my $sa (@ScripActions) {
    # $sa: Name, Description, ExecModule, Argument
    next if exists( $action{ lc($sa->{Name}) } );
    my ($val, $msg) = $ScripAction->Create( %$sa );
    die $msg if !$val;
    $action{ lc($ScripAction->Name) } = [ $ScripAction->Id ];
  }

  # Templates
  my $Template = RT::Template->new($CurrentUser);
  foreach my $t (@Templates) {
    # $t: Queue, Name, Description, Content
    next if exists( $template{ lc($t->{Name}) } );
    my ($val, $msg) = $Template->Create( %$t );
    die $msg if !$val;
    $template{ lc($Template->Name) } = [ $Template->Id ];
  }

  # Scrips
  my %scrip; # $scrips{condition}{action}{template} = id
  my $search = RT::Scrips->new($CurrentUser);
  $search->Limit(FIELD => 'Queue', VALUE => 0);
  while (my $item = $search->Next) {
    my ($c, $a, $t) = map {lc $item->$_->Name} 
      ('ScripConditionObj', 'ScripActionObj', 'TemplateObj');
    if ( exists $scrip{$c}{$a} and $item->Creator == 1 ) {
      warn "Deleting duplicate scrip $c $a [$t]\n";
      my ($val, $msg) = $item->Delete;
      warn "error deleting scrip: $msg\n" if !$val;
    }
    elsif ( exists $Delete_Scrips{$c}{$a}{$t} and $item->Creator == 1 ) {
      warn "Deleting obsolete scrip $c $a [$t]\n";
      my ($val, $msg) = $item->Delete;
      warn "error deleting scrip: $msg\n" if !$val;
    }
    else {
      $scrip{$c}{$a} = $item->id;
    }
  }
  my $Scrip = RT::Scrip->new($CurrentUser);
  foreach my $s ( @Scrips ) {
    my $desc = $s->{'Description'};
    my ($c, $a, $t) = map lc,
      @{ $s }{'ScripCondition', 'ScripAction', 'Template'};

    if ( exists($scrip{$c}{$a}) ) {
      $Scrip->Load( $scrip{$c}{$a} );
    } else { # need to create it

      if ( !exists($condition{$c}) ) {
        warn "ScripCondition '$c' not found.\n";
        next;
      }
      if ( !exists($action{$a}) ) {
        warn "ScripAction '$a' not found.\n";
        next;
      }
      if ( !exists($template{$t}) ) {
        warn "Template '$t' not found.\n";
        next;
      }
      my %new_param = (
        ScripCondition => $condition{$c}->[0],
        ScripAction => $action{$a}->[0],
        Template => $template{$t}->[0],
        Queue => 0,
        Description => $desc,
      );
      warn "Creating scrip: $c $a [$t]\n";
      my ($val, $msg) = $Scrip->Create(%new_param);
      die $msg if !$val;

    } #if $scrip{...}
    # set the Immutable attribute on them if needed
    if ( !$Scrip->FirstAttribute('Immutable') ) {
      my ($val, $msg) =
        $Scrip->SetAttribute(Name => 'Immutable', Content => '1');
      die $msg if !$val;
    }

  } #foreach (@Scrips)

  # one-time fix: accumulator fields (support time, etc.) that had values 
  # entered on ticket creation need OCFV records attached to their Create
  # transactions
  my $sql = 'SELECT first_ocfv.ObjectId, first_ocfv.Created, Content '.
    'FROM ObjectCustomFieldValues as first_ocfv '.
    'JOIN ('.
      # subquery to get the first OCFV with a certain name for each ticket
      'SELECT min(ObjectCustomFieldValues.Id) AS Id '.
      'FROM ObjectCustomFieldValues '.
      'JOIN CustomFields '.
      'ON (ObjectCustomFieldValues.CustomField = CustomFields.Id) '.
      'WHERE ObjectType = \'RT::Ticket\' '.
      'AND CustomFields.Name = ? '.
      'GROUP BY ObjectId'.
    ') AS first_ocfv_id USING (Id) '.
    'JOIN ('.
      # subquery to get the first transaction date for each ticket
      # other than the Create
      'SELECT ObjectId, min(Created) AS Created FROM Transactions '.
      'WHERE ObjectType = \'RT::Ticket\' '.
      'AND Type != \'Create\' '.
      'GROUP BY ObjectId'.
    ') AS first_txn ON (first_ocfv.ObjectId = first_txn.ObjectId) '.
    # where the ticket custom field acquired a value before any transactions
    # on the ticket (i.e. it was set on ticket creation)
    'WHERE first_ocfv.Created < first_txn.Created '.
    # and we haven't already fixed the ticket
    'AND NOT EXISTS('.
      'SELECT 1 FROM Transactions JOIN ObjectCustomFieldValues '.
      'ON (Transactions.Id = ObjectCustomFieldValues.ObjectId) '.
      'JOIN CustomFields '.
      'ON (ObjectCustomFieldValues.CustomField = CustomFields.Id) '.
      'WHERE ObjectCustomFieldValues.ObjectType = \'RT::Transaction\' '.
      'AND CustomFields.Name = ? '.
      'AND Transactions.Type = \'Create\''.
      'AND Transactions.ObjectType = \'RT::Ticket\''.
      'AND Transactions.ObjectId = first_ocfv.ObjectId'.
    ')';
    #whew

  # prior to this fix, the only name an accumulate field could possibly have 
  # was "Support time".
  my $sth = $dbh->prepare($sql);
  $sth->execute('Support time', 'Support time');
  my $rows = $sth->rows;
  warn "Fixing support time on $rows rows...\n" if $rows > 0;
  while ( my $row = $sth->fetchrow_arrayref ) {
    my ($tid, $created, $content) = @$row;
    my $Txns = RT::Transactions->new($CurrentUser);
    $Txns->Limit(FIELD => 'ObjectId', VALUE => $tid);
    $Txns->Limit(FIELD => 'ObjectType', VALUE => 'RT::Ticket');
    $Txns->Limit(FIELD => 'Type', VALUE => 'Create');
    my $CreateTxn = $Txns->First;
    if ($CreateTxn) {
      my ($val, $msg) = $CreateTxn->AddCustomFieldValue(
        Field => 'Support time',
        Value => $content,
        RecordTransaction => 0,
      );
      warn "Error setting transaction support time: $msg\n" unless $val;
    } else {
      warn "Create transaction not found for ticket $tid.\n";
    }
  }

  my $cve_2013_3373_sql = '';
  if ( driver_name =~ /^Pg/i ) {
    $cve_2013_3373_sql = q(
      UPDATE Tickets SET Subject = REPLACE(Subject,E'\n','')
    );
  } elsif ( driver_name =~ /^mysql/i ) {
    $cve_2013_3373_sql = q(
      UPDATE Tickets SET Subject = REPLACE(Subject,'\n','');
    );
  } else {
    warn "WARNING: Don't know how to update RT Ticket Subjects for your database driver for CVE-2013-3373";
  }
  if ( $cve_2013_3373_sql ) {
    my $cve_2013_3373_sth = $dbh->prepare($cve_2013_3373_sql)
      or die $dbh->errstr;
    $cve_2013_3373_sth->execute
      or die $cve_2013_3373_sth->errstr;
  }

  # Remove dangling customer links, if any
  my %target_pkey = ('cust_main' => 'custnum', 'cust_svc' => 'svcnum');
  for my $table (keys %target_pkey) {
    my $pkey = $target_pkey{$table};
    my $rows = $dbh->do(
      "DELETE FROM Links WHERE id IN(
        SELECT id FROM (
          SELECT Links.id FROM Links LEFT JOIN $table ON (Links.Target = 
          'freeside://freeside/$table/' || $table.$pkey)
          WHERE Links.Target like 'freeside://freeside/$table/%'
          AND $table.$pkey IS NULL
        ) AS x
      )"
    ) or die $dbh->errstr;
    warn "Removed $rows dangling ticket-$table links\n" if $rows > 0;
  }

  # Fix ticket transactions on the Time* fields where the NewValue (or
  # OldValue, though this is not known to happen) is an empty string
  foreach (qw(newvalue oldvalue)) {
    my $rows = $dbh->do(
      "UPDATE Transactions SET $_ = '0' WHERE ObjectType='RT::Ticket' AND ".
      "Field IN ('TimeWorked', 'TimeEstimated', 'TimeLeft') AND $_ = ''"
    ) or die $dbh->errstr;
    warn "Fixed $rows transactions with empty time values\n" if $rows > 0;
  }

  return;
}

1;
