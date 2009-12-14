package FS::part_export::sqlradius;

use vars qw(@ISA @EXPORT_OK $DEBUG %info %options $notes1 $notes2);
use Exporter;
use Tie::IxHash;
use FS::Record qw( dbh qsearch qsearchs str2time_sql );
use FS::part_export;
use FS::svc_acct;
use FS::export_svc;
use Carp qw( cluck );

@ISA = qw(FS::part_export);
@EXPORT_OK = qw( sqlradius_connect );

$DEBUG = 0;

tie %options, 'Tie::IxHash',
  'datasrc'  => { label=>'DBI data source ' },
  'username' => { label=>'Database username' },
  'password' => { label=>'Database password' },
  'ignore_accounting' => {
    type  => 'checkbox',
    label => 'Ignore accounting records from this database'
  },
  'hide_ip' => {
    type  => 'checkbox',
    label => 'Hide IP address information on session reports',
  },
  'hide_data' => {
    type  => 'checkbox',
    label => 'Hide download/upload information on session reports',
  },
  'show_called_station' => {
    type  => 'checkbox',
    label => 'Show the Called-Station-ID on session reports',
  },
  'overlimit_groups' => { label => 'Radius groups to assign to svc_acct which has exceeded its bandwidth or time limit (if not overridden by overlimit_groups global or per-agent config)', } ,
  'groups_susp_reason' => { label =>
                             'Radius group mapping to reason (via template user) (svcnum|username|username@domain  reasonnum|reason)',
                            type  => 'textarea',
                          },

;

$notes1 = <<'END';
Real-time export of <b>radcheck</b>, <b>radreply</b> and <b>usergroup</b>
tables to any SQL database for
<a href="http://www.freeradius.org/">FreeRADIUS</a>
or <a href="http://radius.innercite.com/">ICRADIUS</a>.
END

$notes2 = <<'END';
An existing RADIUS database will be updated in realtime, but you can use
<a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.9:Documentation:Developer/bin/freeside-sqlradius-reset">freeside-sqlradius-reset</a>
to delete the entire RADIUS database and repopulate the tables from the
Freeside database.  See the
<a href="http://search.cpan.org/dist/DBI/DBI.pm#connect">DBI documentation</a>
and the
<a href="http://search.cpan.org/search?mode=module&query=DBD%3A%3A">documentation for your DBD</a>
for the exact syntax of a DBI data source.
<ul>
  <li>Using FreeRADIUS 0.9.0 with the PostgreSQL backend, the db_postgresql.sql schema and postgresql.conf queries contain incompatible changes.  This is fixed in 0.9.1.  Only new installs with 0.9.0 and PostgreSQL are affected - upgrades and other database backends and versions are unaffected.
  <li>Using ICRADIUS, add a dummy "op" column to your database:
    <blockquote><code>
      ALTER&nbsp;TABLE&nbsp;radcheck&nbsp;ADD&nbsp;COLUMN&nbsp;op&nbsp;VARCHAR(2)&nbsp;NOT&nbsp;NULL&nbsp;DEFAULT&nbsp;'=='<br>
      ALTER&nbsp;TABLE&nbsp;radreply&nbsp;ADD&nbsp;COLUMN&nbsp;op&nbsp;VARCHAR(2)&nbsp;NOT&nbsp;NULL&nbsp;DEFAULT&nbsp;'=='<br>
      ALTER&nbsp;TABLE&nbsp;radgroupcheck&nbsp;ADD&nbsp;COLUMN&nbsp;op&nbsp;VARCHAR(2)&nbsp;NOT&nbsp;NULL&nbsp;DEFAULT&nbsp;'=='<br>
      ALTER&nbsp;TABLE&nbsp;radgroupreply&nbsp;ADD&nbsp;COLUMN&nbsp;op&nbsp;VARCHAR(2)&nbsp;NOT&nbsp;NULL&nbsp;DEFAULT&nbsp;'=='
    </code></blockquote>
  <li>Using Radiator, see the
    <a href="http://www.open.com.au/radiator/faq.html#38">Radiator FAQ</a>
    for configuration information.
</ul>
END

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Real-time export to SQL-backed RADIUS (FreeRADIUS, ICRADIUS)',
  'options'  => \%options,
  'nodomain' => 'Y',
  'notes'    => $notes1.
                'This export does not export RADIUS realms (see also '.
                'sqlradius_withdomain).  '.
                $notes2
);

sub _groups_susp_reason_map { map { reverse( /^\s*(\S+)\s*(.*)$/ ) } 
                              split( "\n", shift->option('groups_susp_reason'));
}

sub rebless { shift; }

sub export_username {
  my($self, $svc_acct) = (shift, shift);
  warn "export_username called on $self with arg $svc_acct" if $DEBUG > 1;
  $svc_acct->username;
}

sub _export_insert {
  my($self, $svc_x) = (shift, shift);

  foreach my $table (qw(reply check)) {
    my $method = "radius_$table";
    my %attrib = $svc_x->$method();
    next unless keys %attrib;
    my $err_or_queue = $self->sqlradius_queue( $svc_x->svcnum, 'insert',
      $table, $self->export_username($svc_x), %attrib );
    return $err_or_queue unless ref($err_or_queue);
  }
  my @groups = $svc_x->radius_groups;
  if ( @groups ) {
    cluck localtime(). ": queuing usergroup_insert for ". $svc_x->svcnum.
          " (". $self->export_username($svc_x). " with ". join(", ", @groups)
      if $DEBUG;
    my $err_or_queue = $self->sqlradius_queue(
      $svc_x->svcnum, 'usergroup_insert',
      $self->export_username($svc_x), @groups );
    return $err_or_queue unless ref($err_or_queue);
  }
  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $jobnum = '';
  if ( $self->export_username($old) ne $self->export_username($new) ) {
    my $err_or_queue = $self->sqlradius_queue( $new->svcnum, 'rename',
      $self->export_username($new), $self->export_username($old) );
    unless ( ref($err_or_queue) ) {
      $dbh->rollback if $oldAutoCommit;
      return $err_or_queue;
    }
    $jobnum = $err_or_queue->jobnum;
  }

  foreach my $table (qw(reply check)) {
    my $method = "radius_$table";
    my %new = $new->$method();
    my %old = $old->$method();
    if ( grep { !exists $old{$_} #new attributes
                || $new{$_} ne $old{$_} #changed
              } keys %new
    ) {
      my $err_or_queue = $self->sqlradius_queue( $new->svcnum, 'insert',
        $table, $self->export_username($new), %new );
      unless ( ref($err_or_queue) ) {
        $dbh->rollback if $oldAutoCommit;
        return $err_or_queue;
      }
      if ( $jobnum ) {
        my $error = $err_or_queue->depend_insert( $jobnum );
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
      }
    }

    my @del = grep { !exists $new{$_} } keys %old;
    if ( @del ) {
      my $err_or_queue = $self->sqlradius_queue( $new->svcnum, 'attrib_delete',
        $table, $self->export_username($new), @del );
      unless ( ref($err_or_queue) ) {
        $dbh->rollback if $oldAutoCommit;
        return $err_or_queue;
      }
      if ( $jobnum ) {
        my $error = $err_or_queue->depend_insert( $jobnum );
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
      }
    }
  }

  my $error;
  my (@oldgroups) = $old->radius_groups;
  my (@newgroups) = $new->radius_groups;
  $error = $self->sqlreplace_usergroups( $new->svcnum,
                                         $self->export_username($new),
                                         $jobnum ? $jobnum : '',
                                         \@oldgroups,
                                         \@newgroups,
                                       );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

sub _export_suspend {
  my( $self, $svc_acct ) = (shift, shift);

  my $new = $svc_acct->clone_suspended;
  
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $err_or_queue = $self->sqlradius_queue( $new->svcnum, 'insert',
    'check', $self->export_username($new), $new->radius_check );
  unless ( ref($err_or_queue) ) {
    $dbh->rollback if $oldAutoCommit;
    return $err_or_queue;
  }

  my $error;
  my (@newgroups) = $self->suspended_usergroups($svc_acct);
  $error =
    $self->sqlreplace_usergroups( $new->svcnum,
                                  $self->export_username($new),
				  '',
                                  $svc_acct->usergroup,
				  \@newgroups,
				);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

sub _export_unsuspend {
  my( $self, $svc_acct ) = (shift, shift);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $err_or_queue = $self->sqlradius_queue( $svc_acct->svcnum, 'insert',
    'check', $self->export_username($svc_acct), $svc_acct->radius_check );
  unless ( ref($err_or_queue) ) {
    $dbh->rollback if $oldAutoCommit;
    return $err_or_queue;
  }

  my $error;
  my (@oldgroups) = $self->suspended_usergroups($svc_acct);
  $error = $self->sqlreplace_usergroups( $svc_acct->svcnum,
                                         $self->export_username($svc_acct),
                                         '',
					 \@oldgroups,
					 $svc_acct->usergroup,
				       );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

sub _export_delete {
  my( $self, $svc_x ) = (shift, shift);
  my $err_or_queue = $self->sqlradius_queue( $svc_x->svcnum, 'delete',
    $self->export_username($svc_x) );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub sqlradius_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::sqlradius::sqlradius_$method",
  };
  $queue->insert(
    $self->option('datasrc'),
    $self->option('username'),
    $self->option('password'),
    @_,
  ) or $queue;
}

sub suspended_usergroups {
  my ($self, $svc_acct) = (shift, shift);

  return () unless $svc_acct;

  #false laziness with FS::part_export::shellcommands
  #subclass part_export?

  my $r = $svc_acct->cust_svc->cust_pkg->last_reason('susp');
  my %reasonmap = $self->_groups_susp_reason_map;
  my $userspec = '';
  if ($r) {
    $userspec = $reasonmap{$r->reasonnum}
      if exists($reasonmap{$r->reasonnum});
    $userspec = $reasonmap{$r->reason}
      if (!$userspec && exists($reasonmap{$r->reason}));
  }
  my $suspend_user;
  if ($userspec =~ /^d+$/ ){
    $suspend_user = qsearchs( 'svc_acct', { 'svcnum' => $userspec } );
  }elsif ($userspec =~ /^\S+\@\S+$/){
    my ($username,$domain) = split(/\@/, $userspec);
    for my $user (qsearch( 'svc_acct', { 'username' => $username } )){
      $suspend_user = $user if $userspec eq $user->email;
    }
  }elsif ($userspec){
    $suspend_user = qsearchs( 'svc_acct', { 'username' => $userspec } );
  }
  #esalf
  return $suspend_user->radius_groups if $suspend_user;
  ();
}

sub sqlradius_insert { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my( $table, $username, %attributes ) = @_;

  foreach my $attribute ( keys %attributes ) {
  
    my $s_sth = $dbh->prepare(
      "SELECT COUNT(*) FROM rad$table WHERE UserName = ? AND Attribute = ?"
    ) or die $dbh->errstr;
    $s_sth->execute( $username, $attribute ) or die $s_sth->errstr;

    if ( $s_sth->fetchrow_arrayref->[0] ) {

      my $u_sth = $dbh->prepare(
        "UPDATE rad$table SET Value = ? WHERE UserName = ? AND Attribute = ?"
      ) or die $dbh->errstr;
      $u_sth->execute($attributes{$attribute}, $username, $attribute)
        or die $u_sth->errstr;

    } else {

      my $i_sth = $dbh->prepare(
        "INSERT INTO rad$table ( UserName, Attribute, op, Value ) ".
          "VALUES ( ?, ?, ?, ? )"
      ) or die $dbh->errstr;
      $i_sth->execute(
        $username,
        $attribute,
        ( $attribute eq 'Password' ? '==' : ':=' ),
        $attributes{$attribute},
      ) or die $i_sth->errstr;

    }

  }
  $dbh->disconnect;
}

sub sqlradius_usergroup_insert { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my( $username, @groups ) = @_;

  my $s_sth = $dbh->prepare(
    "SELECT COUNT(*) FROM usergroup WHERE UserName = ? AND GroupName = ?"
  ) or die $dbh->errstr;

  my $sth = $dbh->prepare( 
    "INSERT INTO usergroup ( UserName, GroupName ) VALUES ( ?, ? )"
  ) or die $dbh->errstr;

  foreach my $group ( @groups ) {
    $s_sth->execute( $username, $group ) or die $s_sth->errstr;
    if ($s_sth->fetchrow_arrayref->[0]) {
      warn localtime() . ": sqlradius_usergroup_insert attempted to reinsert " .
           "$group for $username\n"
        if $DEBUG;
      next;
    }
    $sth->execute( $username, $group )
      or die "can't insert into groupname table: ". $sth->errstr;
  }
  $dbh->disconnect;
}

sub sqlradius_usergroup_delete { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my( $username, @groups ) = @_;

  my $sth = $dbh->prepare( 
    "DELETE FROM usergroup WHERE UserName = ? AND GroupName = ?"
  ) or die $dbh->errstr;
  foreach my $group ( @groups ) {
    $sth->execute( $username, $group )
      or die "can't delete from groupname table: ". $sth->errstr;
  }
  $dbh->disconnect;
}

sub sqlradius_rename { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my($new_username, $old_username) = @_;
  foreach my $table (qw(radreply radcheck usergroup )) {
    my $sth = $dbh->prepare("UPDATE $table SET Username = ? WHERE UserName = ?")
      or die $dbh->errstr;
    $sth->execute($new_username, $old_username)
      or die "can't update $table: ". $sth->errstr;
  }
  $dbh->disconnect;
}

sub sqlradius_attrib_delete { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my( $table, $username, @attrib ) = @_;

  foreach my $attribute ( @attrib ) {
    my $sth = $dbh->prepare(
        "DELETE FROM rad$table WHERE UserName = ? AND Attribute = ?" )
      or die $dbh->errstr;
    $sth->execute($username,$attribute)
      or die "can't delete from rad$table table: ". $sth->errstr;
  }
  $dbh->disconnect;
}

sub sqlradius_delete { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my $username = shift;

  foreach my $table (qw( radcheck radreply usergroup )) {
    my $sth = $dbh->prepare( "DELETE FROM $table WHERE UserName = ?" );
    $sth->execute($username)
      or die "can't delete from $table table: ". $sth->errstr;
  }
  $dbh->disconnect;
}

sub sqlradius_connect {
  #my($datasrc, $username, $password) = @_;
  #DBI->connect($datasrc, $username, $password) or die $DBI::errstr;
  DBI->connect(@_) or die $DBI::errstr;
}

sub sqlreplace_usergroups {
  my ($self, $svcnum, $username, $jobnum, $old, $new) = @_;

  # (sorta) false laziness with FS::svc_acct::replace
  my @oldgroups = @$old;
  my @newgroups = @$new;
  my @delgroups = ();
  foreach my $oldgroup ( @oldgroups ) {
    if ( grep { $oldgroup eq $_ } @newgroups ) {
      @newgroups = grep { $oldgroup ne $_ } @newgroups;
      next;
    }
    push @delgroups, $oldgroup;
  }

  if ( @delgroups ) {
    my $err_or_queue = $self->sqlradius_queue( $svcnum, 'usergroup_delete',
      $username, @delgroups );
    return $err_or_queue
      unless ref($err_or_queue);
    if ( $jobnum ) {
      my $error = $err_or_queue->depend_insert( $jobnum );
      return $error if $error;
    }
  }

  if ( @newgroups ) {
    cluck localtime(). ": queuing usergroup_insert for $svcnum ($username) ".
          "with ".  join(", ", @newgroups)
      if $DEBUG;
    my $err_or_queue = $self->sqlradius_queue( $svcnum, 'usergroup_insert',
      $username, @newgroups );
    return $err_or_queue
      unless ref($err_or_queue);
    if ( $jobnum ) {
      my $error = $err_or_queue->depend_insert( $jobnum );
      return $error if $error;
    }
  }
  '';
}


#--

=item usage_sessions HASHREF

=item usage_sessions TIMESTAMP_START TIMESTAMP_END [ SVC_ACCT [ IP [ PREFIX [ SQL_SELECT ] ] ] ]

New-style: pass a hashref with the following keys:

=over 4

=item stoptime_start - Lower bound for AcctStopTime, as a UNIX timestamp

=item stoptime_end - Upper bound for AcctStopTime, as a UNIX timestamp

=item open_sessions - Only show records with no AcctStopTime (typically used without stoptime_* options and with starttime_* options instead)

=item starttime_start - Lower bound for AcctStartTime, as a UNIX timestamp

=item starttime_end - Upper bound for AcctStartTime, as a UNIX timestamp

=item svc_acct

=item ip

=item prefix

=back

Old-style: 

TIMESTAMP_START and TIMESTAMP_END are specified as UNIX timestamps; see
L<perlfunc/"time">.  Also see L<Time::Local> and L<Date::Parse> for conversion
functions.

SVC_ACCT, if specified, limits the results to the specified account.

IP, if specified, limits the results to the specified IP address.

PREFIX, if specified, limits the results to records with a matching
Called-Station-ID.

#SQL_SELECT defaults to * if unspecified.  It can be useful to set it to 
#SUM(acctsessiontime) or SUM(AcctInputOctets), etc.

Returns an arrayref of hashrefs with the following fields:

=over 4

=item username

=item framedipaddress

=item acctstarttime

=item acctstoptime

=item acctsessiontime

=item acctinputoctets

=item acctoutputoctets

=item calledstationid

=back

=cut

#some false laziness w/cust_svc::seconds_since_sqlradacct

sub usage_sessions {
  my( $self ) = shift;

  my $opt = {};
  my($start, $end, $svc_acct, $ip, $prefix) = ( '', '', '', '', '');
  if ( ref($_[0]) ) {
    $opt = shift;
    $start    = $opt->{stoptime_start};
    $end      = $opt->{stoptime_end};
    $svc_acct = $opt->{svc_acct};
    $ip       = $opt->{ip};
    $prefix   = $opt->{prefix};
  } else {
    ( $start, $end ) = splice(@_, 0, 2);
    $svc_acct = @_ ? shift : '';
    $ip = @_ ? shift : '';
    $prefix = @_ ? shift : '';
    #my $select = @_ ? shift : '*';
  }

  $end ||= 2147483647;

  return [] if $self->option('ignore_accounting');

  my $dbh = sqlradius_connect( map $self->option($_),
                                   qw( datasrc username password ) );

  #select a unix time conversion function based on database type
  my $str2time = str2time_sql( $dbh->{Driver}->{Name} );

  my @fields = (
                 qw( username realm framedipaddress
                     acctsessiontime acctinputoctets acctoutputoctets
                     calledstationid
                   ),
                 "$str2time acctstarttime ) as acctstarttime",
                 "$str2time acctstoptime ) as acctstoptime",
               );

  my @param = ();
  my @where = ();

  if ( $svc_acct ) {
    my $username = $self->export_username($svc_acct);
    if ( $svc_acct =~ /^([^@]+)\@([^@]+)$/ ) {
      push @where, '( UserName = ? OR ( UserName = ? AND Realm = ? ) )';
      push @param, $username, $1, $2;
    } else {
      push @where, 'UserName = ?';
      push @param, $username;
    }
  }

  if ( length($ip) ) {
    push @where, ' FramedIPAddress = ?';
    push @param, $ip;
  }

  if ( length($prefix) ) {
    #assume sip: for now, else things get ugly trying to match /^\w+:$prefix/
    push @where, " CalledStationID LIKE 'sip:$prefix\%'";
  }

  if ( $start ) {
    push @where, "$str2time AcctStopTime ) >= ?";
    push @param, $start;
  }
  if ( $end ) {
    push @where, "$str2time AcctStopTime ) <= ?";
    push @param, $end;
  }
  if ( $opt->{open_sessions} ) {
    push @where, 'AcctStopTime IS NULL';
  }
  if ( $opt->{starttime_start} ) {
    push @where, "$str2time AcctStartTime ) >= ?";
    push @param, $opt->{starttime_start};
  }
  if ( $opt->{starttime_end} ) {
    push @where, "$str2time AcctStartTime ) <= ?";
    push @param, $opt->{starttime_end};
  }

  my $where = join(' AND ', @where);
  $where = "WHERE $where" if $where;

  my $sth = $dbh->prepare('SELECT '. join(', ', @fields).
                          "  FROM radacct
                             $where
                             ORDER BY AcctStartTime DESC
  ") or die $dbh->errstr;                                 
  $sth->execute(@param) or die $sth->errstr;

  [ map { { %$_ } } @{ $sth->fetchall_arrayref({}) } ];

}

=item update_svc_acct

=cut

sub update_svc {
  my $self = shift;

  my $conf = new FS::Conf;

  my $fdbh = dbh;
  my $dbh = sqlradius_connect( map $self->option($_),
                                   qw( datasrc username password ) );

  my $str2time = str2time_sql( $dbh->{Driver}->{Name} );
  my @fields = qw( radacctid username realm acctsessiontime );

  my @param = ();
  my $where = '';

  my $sth = $dbh->prepare("
    SELECT RadAcctId, UserName, Realm, AcctSessionTime,
           $str2time AcctStartTime),  $str2time AcctStopTime), 
           AcctInputOctets, AcctOutputOctets
      FROM radacct
      WHERE FreesideStatus IS NULL
        AND AcctStopTime != 0
  ") or die $dbh->errstr;
  $sth->execute() or die $sth->errstr;

  while ( my $row = $sth->fetchrow_arrayref ) {
    my($RadAcctId, $UserName, $Realm, $AcctSessionTime, $AcctStartTime,
       $AcctStopTime, $AcctInputOctets, $AcctOutputOctets) = @$row;
    warn "processing record: ".
         "$RadAcctId ($UserName\@$Realm for ${AcctSessionTime}s"
      if $DEBUG;

    $UserName = lc($UserName) unless $conf->exists('username-uppercase');

    #my %search = ( 'username' => $UserName );

    my $extra_sql = '';
    if ( ref($self) =~ /withdomain/ ) { #well...
      $extra_sql = " AND '$Realm' = ( SELECT domain FROM svc_domain
                          WHERE svc_domain.svcnum = svc_acct.domsvc ) ";
    }

    my $oldAutoCommit = $FS::UID::AutoCommit; # can't undo side effects, but at
    local $FS::UID::AutoCommit = 0;           # least we can avoid over counting

    my @svc_acct =
      grep { qsearch( 'export_svc', { 'exportnum' => $self->exportnum,
                                      'svcpart'   => $_->cust_svc->svcpart, } )
           }
      qsearch( 'svc_acct',
                 { 'username' => $UserName },
                 '',
                 $extra_sql
               );

    my $errinfo = "for RADIUS detail RadAcctID $RadAcctId ".
                  "(UserName $UserName, Realm $Realm)";
    my $status = 'skipped';
    if ( !@svc_acct ) {
      warn "WARNING: no svc_acct record found $errinfo - skipping\n";
    } elsif ( scalar(@svc_acct) > 1 ) {
      warn "WARNING: multiple svc_acct records found $errinfo - skipping\n";
    } else {

      my $svc_acct = $svc_acct[0];
      warn "found svc_acct ". $svc_acct->svcnum. " $errinfo\n" if $DEBUG;

      $svc_acct->last_login($AcctStartTime);
      $svc_acct->last_logout($AcctStopTime);

      my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
      if ( $cust_pkg && $AcctStopTime < (    $cust_pkg->last_bill
                                          || $cust_pkg->setup     )  ) {
        $status = 'skipped (too old)';
      } else {
        my @st;
        push @st, _try_decrement($svc_acct, 'seconds',    $AcctSessionTime   );
        push @st, _try_decrement($svc_acct, 'upbytes',    $AcctInputOctets   );
        push @st, _try_decrement($svc_acct, 'downbytes',  $AcctOutputOctets  );
        push @st, _try_decrement($svc_acct, 'totalbytes', $AcctInputOctets
                                                          + $AcctOutputOctets);
        $status=join(' ', @st);
      }
    }

    warn "setting FreesideStatus to $status $errinfo\n" if $DEBUG; 
    my $psth = $dbh->prepare("UPDATE radacct
                                SET FreesideStatus = ?
                                WHERE RadAcctId = ?"
    ) or die $dbh->errstr;
    $psth->execute($status, $RadAcctId) or die $psth->errstr;

    $fdbh->commit or die $fdbh->errstr if $oldAutoCommit;

  }

}

sub _try_decrement {
  my ($svc_acct, $column, $amount) = @_;
  if ( $svc_acct->$column !~ /^$/ ) {
    warn "  svc_acct.$column found (". $svc_acct->$column.
         ") - decrementing\n"
      if $DEBUG;
    my $method = 'decrement_' . $column;
    my $error = $svc_acct->$method($amount);
    die $error if $error;
    return 'done';
  } else {
    warn "  no existing $column value for svc_acct - skipping\n" if $DEBUG;
  }
  return 'skipped';
}

###
#class methods
###

sub all_sqlradius {
  #my $class = shift;

  #don't just look for ->can('usage_sessions'), we're sqlradius-specific
  # (radiator is supposed to be setup with a radacct table)
  #i suppose it would be more slick to look for things that inherit from us..

  my @part_export = ();
  push @part_export, qsearch('part_export', { 'exporttype' => $_ } )
    foreach qw( sqlradius sqlradius_withdomain radiator phone_sqlradius );
  @part_export;
}

sub all_sqlradius_withaccounting {
  my $class = shift;
  grep { ! $_->option('ignore_accounting') } $class->all_sqlradius;
}

1;

