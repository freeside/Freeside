package FS::part_export::sqlradius;

use strict;
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

my %groups;
tie %options, 'Tie::IxHash',
  'datasrc'  => { label=>'DBI data source ' },
  'username' => { label=>'Database username' },
  'password' => { label=>'Database password' },
  'usergroup' => { label   => 'Group table',
                   type    => 'select',
                   options => [qw( usergroup radusergroup ) ],
                 },
  'ignore_accounting' => {
    type  => 'checkbox',
    label => 'Ignore accounting records from this database'
  },
  'process_single_realm' => {
    type  => 'checkbox',
    label => 'Only process one realm of accounting records',
  },
  'realm' => { label => 'The realm of of accounting records to be processed' },
  'ignore_long_sessions' => {
    type  => 'checkbox',
    label => 'Ignore sessions which span billing periods',
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
  'overlimit_groups' => {
      label => 'Radius groups to assign to svc_acct which has exceeded its bandwidth or time limit (if not overridden by overlimit_groups global or per-agent config)', 
      type  => 'select',
      multi => 1,
      option_label  => sub {
        $groups{$_[0]};
      },
      option_values => sub {
        %groups = (
              map { $_->groupnum, $_->long_description } 
                  qsearch('radius_group', {}),
            );
            sort keys (%groups);
      },
   } ,
  'groups_susp_reason' => { label =>
                             'Radius group mapping to reason (via template user) (svcnum|username|username@domain  reasonnum|reason)',
                            type  => 'textarea',
                          },
  'export_attrs' => {
    type => 'checkbox',
    label => 'Export RADIUS group attributes to this database',
  },
;

$notes1 = <<'END';
Real-time export of <b>radcheck</b>, <b>radreply</b> and <b>usergroup</b>/<b>radusergroup</b>
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
  'nas'      => 'Y', # show export_nas selection in UI
  'default_svc_class' => 'Internet',
  'notes'    => $notes1.
                'This export does not export RADIUS realms (see also '.
                'sqlradius_withdomain).  '.
                $notes2
);

sub _groups_susp_reason_map { map { reverse( /^\s*(\S+)\s*(.*)$/ ) } 
                              split( "\n", shift->option('groups_susp_reason'));
}

sub rebless { shift; }

sub export_username { # override for other svcdb
  my($self, $svc_acct) = (shift, shift);
  warn "export_username called on $self with arg $svc_acct" if $DEBUG > 1;
  $svc_acct->username;
}

sub radius_reply { #override for other svcdb
  my($self, $svc_acct) = (shift, shift);
  $svc_acct->radius_reply;
}

sub radius_check { #override for other svcdb
  my($self, $svc_acct) = (shift, shift);
  $svc_acct->radius_check;
}

sub _export_insert {
  my($self, $svc_x) = (shift, shift);

  foreach my $table (qw(reply check)) {
    my $method = "radius_$table";
    my %attrib = $self->$method($svc_x);
    next unless keys %attrib;
    my $err_or_queue = $self->sqlradius_queue( $svc_x->svcnum, 'insert',
      $table, $self->export_username($svc_x), %attrib );
    return $err_or_queue unless ref($err_or_queue);
  }
  my @groups = $svc_x->radius_groups('hashref');
  if ( @groups ) {
    cluck localtime(). ": queuing usergroup_insert for ". $svc_x->svcnum.
          " (". $self->export_username($svc_x). " with ". join(", ", @groups)
      if $DEBUG;
    my $usergroup = $self->option('usergroup') || 'usergroup';
    my $err_or_queue = $self->sqlradius_queue(
      $svc_x->svcnum, 'usergroup_insert',
      $self->export_username($svc_x), $usergroup, @groups );
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
    my $usergroup = $self->option('usergroup') || 'usergroup';
    my $err_or_queue = $self->sqlradius_queue( $new->svcnum, 'rename',
      $self->export_username($new), $self->export_username($old), $usergroup );
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
  my (@oldgroups) = $old->radius_groups('hashref');
  my (@newgroups) = $new->radius_groups('hashref');
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

#false laziness w/broadband_sqlradius.pm
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

  my @newgroups = $self->suspended_usergroups($svc_acct);

  unless (@newgroups) { #don't change password if assigning to a suspended group

    my $err_or_queue = $self->sqlradius_queue( $new->svcnum, 'insert',
      'check', $self->export_username($new), $new->radius_check );
    unless ( ref($err_or_queue) ) {
      $dbh->rollback if $oldAutoCommit;
      return $err_or_queue;
    }

  }

  my $error =
    $self->sqlreplace_usergroups(
      $new->svcnum,
      $self->export_username($new),
      '',
      [ $svc_acct->radius_groups('hashref') ],
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
  my( $self, $svc_x ) = (shift, shift);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $err_or_queue = $self->sqlradius_queue( $svc_x->svcnum, 'insert',
    'check', $self->export_username($svc_x), $self->radius_check($svc_x) );
  unless ( ref($err_or_queue) ) {
    $dbh->rollback if $oldAutoCommit;
    return $err_or_queue;
  }

  my $error;
  my (@oldgroups) = $self->suspended_usergroups($svc_x);
  $error = $self->sqlreplace_usergroups(
    $svc_x->svcnum,
    $self->export_username($svc_x),
    '',
    \@oldgroups,
    [ $svc_x->radius_groups('hashref') ],
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
  my $usergroup = $self->option('usergroup') || 'usergroup';
  my $err_or_queue = $self->sqlradius_queue( $svc_x->svcnum, 'delete',
    $self->export_username($svc_x), $usergroup );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub sqlradius_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my %args = @_;
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
  my ($self, $svc_x) = (shift, shift);

  return () unless $svc_x;

  my $svc_table = $svc_x->table;

  #false laziness with FS::part_export::shellcommands
  #subclass part_export?

  my $r = $svc_x->cust_svc->cust_pkg->last_reason('susp');
  my %reasonmap = $self->_groups_susp_reason_map;
  my $userspec = '';
  if ($r) {
    $userspec = $reasonmap{$r->reasonnum}
      if exists($reasonmap{$r->reasonnum});
    $userspec = $reasonmap{$r->reason}
      if (!$userspec && exists($reasonmap{$r->reason}));
  }
  my $suspend_svc;
  if ( $userspec =~ /^\d+$/ ){
    $suspend_svc = qsearchs( $svc_table, { 'svcnum' => $userspec } );
  } elsif ( $userspec =~ /^\S+\@\S+$/ && $svc_table eq 'svc_acct' ){
    my ($username,$domain) = split(/\@/, $userspec);
    for my $user (qsearch( 'svc_acct', { 'username' => $username } )){
      $suspend_svc = $user if $userspec eq $user->email;
    }
  }elsif ( $userspec && $svc_table eq 'svc_acct'  ){
    $suspend_svc = qsearchs( 'svc_acct', { 'username' => $userspec } );
  }
  #esalf
  return $suspend_svc->radius_groups('hashref') if $suspend_svc;
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
  my $username = shift;
  my $usergroup = ( $_[0] =~ /^(rad)?usergroup/i ) ? shift : 'usergroup';
  my @groups = @_;

  my $s_sth = $dbh->prepare(
    "SELECT COUNT(*) FROM $usergroup WHERE UserName = ? AND GroupName = ?"
  ) or die $dbh->errstr;

  my $sth = $dbh->prepare( 
    "INSERT INTO $usergroup ( UserName, GroupName, Priority ) VALUES ( ?, ?, ? )"
  ) or die $dbh->errstr;

  foreach ( @groups ) {
    my $group = $_->{'groupname'};
    my $priority = $_->{'priority'};
    $s_sth->execute( $username, $group ) or die $s_sth->errstr;
    if ($s_sth->fetchrow_arrayref->[0]) {
      warn localtime() . ": sqlradius_usergroup_insert attempted to reinsert " .
           "$group for $username\n"
        if $DEBUG;
      next;
    }
    $sth->execute( $username, $group, $priority )
      or die "can't insert into groupname table: ". $sth->errstr;
  }
  if ( $s_sth->{Active} ) {
    warn "sqlradius s_sth still active; calling ->finish()";
    $s_sth->finish;
  }
  if ( $sth->{Active} ) {
    warn "sqlradius sth still active; calling ->finish()";
    $sth->finish;
  }
  $dbh->disconnect;
}

sub sqlradius_usergroup_delete { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my $username = shift;
  my $usergroup = ( $_[0] =~ /^(rad)?usergroup/i ) ? shift : 'usergroup';
  my @groups = @_;

  my $sth = $dbh->prepare( 
    "DELETE FROM $usergroup WHERE UserName = ? AND GroupName = ?"
  ) or die $dbh->errstr;
  foreach ( @groups ) {
    my $group = $_->{'groupname'};
    $sth->execute( $username, $group )
      or die "can't delete from groupname table: ". $sth->errstr;
  }
  $dbh->disconnect;
}

sub sqlradius_rename { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my($new_username, $old_username) = (shift, shift);
  my $usergroup = ( $_[0] =~ /^(rad)?usergroup/i ) ? shift : 'usergroup';
  foreach my $table (qw(radreply radcheck), $usergroup ) {
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
  my $usergroup = ( $_[0] =~ /^(rad)?usergroup/i ) ? shift : 'usergroup';

  foreach my $table (qw( radcheck radreply), $usergroup ) {
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

  my $usergroup = $self->option('usergroup') || 'usergroup';

  if ( @delgroups ) {
    my $err_or_queue = $self->sqlradius_queue( $svcnum, 'usergroup_delete',
      $username, $usergroup, @delgroups );
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
      $username, $usergroup, @newgroups );
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
  my $summarize = 0;
  if ( ref($_[0]) ) {
    $opt = shift;
    $start    = $opt->{stoptime_start};
    $end      = $opt->{stoptime_end};
    $svc_acct = $opt->{svc_acct};
    $ip       = $opt->{ip};
    $prefix   = $opt->{prefix};
    $summarize   = $opt->{summarize};
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

  @fields = ( 'username', 'sum(acctsessiontime) as acctsessiontime', 'sum(acctinputoctets) as acctinputoctets',
              'sum(acctoutputoctets) as acctoutputoctets',
            ) if $summarize;

  my @param = ();
  my @where = ();

  if ( $svc_acct ) {
    my $username = $self->export_username($svc_acct);
    if ( $username =~ /^([^@]+)\@([^@]+)$/ ) {
      push @where, '( UserName = ? OR ( UserName = ? AND Realm = ? ) )';
      push @param, $username, $1, $2;
    } else {
      push @where, 'UserName = ?';
      push @param, $username;
    }
  }

  if ($self->option('process_single_realm')) {
    push @where, 'Realm = ?';
    push @param, $self->option('realm');
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

  my $groupby = '';
  $groupby = 'GROUP BY username' if $summarize;

  my $orderby = 'ORDER BY AcctStartTime DESC';
  $orderby = '' if $summarize;

  my $sth = $dbh->prepare('SELECT '. join(', ', @fields).
                          "  FROM radacct $where $groupby $orderby
                        ") or die $dbh->errstr;                                 
  $sth->execute(@param) or die $sth->errstr;

  [ map { { %$_ } } @{ $sth->fetchall_arrayref({}) } ];

}

=item update_svc

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
        AND AcctStopTime IS NOT NULL
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

    my $status = 'skipped';
    my $errinfo = "for RADIUS detail RadAcctID $RadAcctId ".
                  "(UserName $UserName, Realm $Realm)";

    if (    $self->option('process_single_realm')
         && $self->option('realm') ne $Realm )
    {
      warn "WARNING: wrong realm $errinfo - skipping\n" if $DEBUG;
    } else {
      my @svc_acct =
        grep { qsearch( 'export_svc', { 'exportnum' => $self->exportnum,
                                        'svcpart'   => $_->cust_svc->svcpart, } )
             }
        qsearch( 'svc_acct',
                   { 'username' => $UserName },
                   '',
                   $extra_sql
                 );

      if ( !@svc_acct ) {
        warn "WARNING: no svc_acct record found $errinfo - skipping\n";
      } elsif ( scalar(@svc_acct) > 1 ) {
        warn "WARNING: multiple svc_acct records found $errinfo - skipping\n";
      } else {

        my $svc_acct = $svc_acct[0];
        warn "found svc_acct ". $svc_acct->svcnum. " $errinfo\n" if $DEBUG;

        $svc_acct->last_login($AcctStartTime);
        $svc_acct->last_logout($AcctStopTime);

        my $session_time = $AcctStopTime;
        $session_time = $AcctStartTime if $self->option('ignore_long_sessions');

        my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
        if ( $cust_pkg && $session_time < (    $cust_pkg->last_bill
                                            || $cust_pkg->setup     )  ) {
          $status = 'skipped (too old)';
        } else {
          my @st;
          push @st, _try_decrement($svc_acct, 'seconds',    $AcctSessionTime);
          push @st, _try_decrement($svc_acct, 'upbytes',    $AcctInputOctets);
          push @st, _try_decrement($svc_acct, 'downbytes',  $AcctOutputOctets);
          push @st, _try_decrement($svc_acct, 'totalbytes', $AcctInputOctets
                                                          + $AcctOutputOctets);
          $status=join(' ', @st);
        }
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

=item export_nas_insert NAS

=item export_nas_delete NAS

=item export_nas_replace NEW_NAS OLD_NAS

Update the NAS table (allowed RADIUS clients) on the attached RADIUS 
server.  Currently requires the table to be named 'nas' and to follow 
the stock schema (/etc/freeradius/nas.sql).

=cut

sub export_nas_insert {  shift->export_nas_action('insert', @_); }
sub export_nas_delete {  shift->export_nas_action('delete', @_); }
sub export_nas_replace { shift->export_nas_action('replace', @_); }

sub export_nas_action {
  my $self = shift;
  my ($action, $new, $old) = @_;
  # find the NAS in the target table by its name
  my $nasname = ($action eq 'replace') ? $old->nasname : $new->nasname;
  my $nasnum = $new->nasnum;

  my $err_or_queue = $self->sqlradius_queue('', "nas_$action", 
    nasname => $nasname,
    nasnum => $nasnum
  );
  return $err_or_queue unless ref $err_or_queue;
  '';
}

sub sqlradius_nas_insert {
  my $dbh = sqlradius_connect(shift, shift, shift);
  my %opt = @_;
  my $nas = qsearchs('nas', { nasnum => $opt{'nasnum'} })
    or die "nasnum ".$opt{'nasnum'}.' not found';
  # insert actual NULLs where FS::Record has translated to empty strings
  my @values = map { length($nas->$_) ? $nas->$_ : undef }
    qw( nasname shortname type secret server community description );
  my $sth = $dbh->prepare('INSERT INTO nas 
(nasname, shortname, type, secret, server, community, description)
VALUES (?, ?, ?, ?, ?, ?, ?)');
  $sth->execute(@values) or die $dbh->errstr;
}

sub sqlradius_nas_delete {
  my $dbh = sqlradius_connect(shift, shift, shift);
  my %opt = @_;
  my $sth = $dbh->prepare('DELETE FROM nas WHERE nasname = ?');
  $sth->execute($opt{'nasname'}) or die $dbh->errstr;
}

sub sqlradius_nas_replace {
  my $dbh = sqlradius_connect(shift, shift, shift);
  my %opt = @_;
  my $nas = qsearchs('nas', { nasnum => $opt{'nasnum'} })
    or die "nasnum ".$opt{'nasnum'}.' not found';
  my @values = map {$nas->$_} 
    qw( nasname shortname type secret server community description );
  my $sth = $dbh->prepare('UPDATE nas SET
    nasname = ?, shortname = ?, type = ?, secret = ?,
    server = ?, community = ?, description = ?
    WHERE nasname = ?');
  $sth->execute(@values, $opt{'nasname'}) or die $dbh->errstr;
}

=item export_attr_insert RADIUS_ATTR

=item export_attr_delete RADIUS_ATTR

=item export_attr_replace NEW_RADIUS_ATTR OLD_RADIUS_ATTR

Update the group attribute tables (radgroupcheck and radgroupreply) on
the RADIUS server.  In delete and replace actions, the existing records
are identified by the combination of group name and attribute name.

In the special case where attributes are being replaced because a group 
name (L<FS::radius_group>->groupname) is changing, the pseudo-field 
'groupname' must be set in OLD_RADIUS_ATTR.

=cut

# some false laziness with NAS export stuff...

sub export_attr_insert  { shift->export_attr_action('insert', @_); }

sub export_attr_delete  { shift->export_attr_action('delete', @_); }

sub export_attr_replace { shift->export_attr_action('replace', @_); }

sub export_attr_action {
  my $self = shift;
  my ($action, $new, $old) = @_;
  my $err_or_queue;

  if ( $action eq 'delete' ) {
    $old = $new;
  }
  if ( $action eq 'delete' or $action eq 'replace' ) {
    # delete based on an exact match
    my %opt = (
      attrname  => $old->attrname,
      attrtype  => $old->attrtype,
      groupname => $old->groupname || $old->radius_group->groupname,
      op        => $old->op,
      value     => $old->value,
    );
    $err_or_queue = $self->sqlradius_queue('', 'attr_delete', %opt);
    return $err_or_queue unless ref $err_or_queue;
  }
  # this probably doesn't matter, but just to be safe...
  my $jobnum = $err_or_queue->jobnum if $action eq 'replace';
  if ( $action eq 'replace' or $action eq 'insert' ) {
    my %opt = (
      attrname  => $new->attrname,
      attrtype  => $new->attrtype,
      groupname => $new->radius_group->groupname,
      op        => $new->op,
      value     => $new->value,
    );
    $err_or_queue = $self->sqlradius_queue('', 'attr_insert', %opt);
    $err_or_queue->depend_insert($jobnum) if $jobnum;
    return $err_or_queue unless ref $err_or_queue;
  }
  '';
}

sub sqlradius_attr_insert {
  my $dbh = sqlradius_connect(shift, shift, shift);
  my %opt = @_;

  my $table;
  # make sure $table is completely safe
  if ( $opt{'attrtype'} eq 'C' ) {
    $table = 'radgroupcheck';
  }
  elsif ( $opt{'attrtype'} eq 'R' ) {
    $table = 'radgroupreply';
  }
  else {
    die "unknown attribute type '$opt{attrtype}'";
  }

  my @values = @opt{ qw(groupname attrname op value) };
  my $sth = $dbh->prepare(
    'INSERT INTO '.$table.' (groupname, attribute, op, value) VALUES (?,?,?,?)'
  );
  $sth->execute(@values) or die $dbh->errstr;
}

sub sqlradius_attr_delete {
  my $dbh = sqlradius_connect(shift, shift, shift);
  my %opt = @_;

  my $table;
  if ( $opt{'attrtype'} eq 'C' ) {
    $table = 'radgroupcheck';
  }
  elsif ( $opt{'attrtype'} eq 'R' ) {
    $table = 'radgroupreply';
  }
  else {
    die "unknown attribute type '".$opt{'attrtype'}."'";
  }

  my @values = @opt{ qw(groupname attrname op value) };
  my $sth = $dbh->prepare(
    'DELETE FROM '.$table.
    ' WHERE groupname = ? AND attribute = ? AND op = ? AND value = ?'.
    ' LIMIT 1'
  );
  $sth->execute(@values) or die $dbh->errstr;
}

#sub sqlradius_attr_replace { no longer needed

=item export_group_replace NEW OLD

Replace the L<FS::radius_group> object OLD with NEW.  This will change
the group name and priority in all radusergroup records, and the group 
name in radgroupcheck and radgroupreply.

=cut

sub export_group_replace {
  my $self = shift;
  my ($new, $old) = @_;
  return '' if $new->groupname eq $old->groupname
           and $new->priority  == $old->priority;

  my $err_or_queue = $self->sqlradius_queue(
    '',
    'group_replace',
    ($self->option('usergroup') || 'usergroup'),
    $new->hashref,
    $old->hashref,
  );
  return $err_or_queue unless ref $err_or_queue;
  '';
}

sub sqlradius_group_replace {
  my $dbh = sqlradius_connect(shift, shift, shift);
  my $usergroup = shift;
  $usergroup =~ /^(rad)?usergroup$/
    or die "bad usergroup table name: $usergroup";
  my ($new, $old) = (shift, shift);
  # apply renames to check/reply attribute tables
  if ( $new->{'groupname'} ne $old->{'groupname'} ) {
    foreach my $table (qw(radgroupcheck radgroupreply)) {
      my $sth = $dbh->prepare(
        'UPDATE '.$table.' SET groupname = ? WHERE groupname = ?'
      );
      $sth->execute($new->{'groupname'}, $old->{'groupname'})
        or die $dbh->errstr;
    }
  }
  # apply renames and priority changes to usergroup table
  my $sth = $dbh->prepare(
    'UPDATE '.$usergroup.' SET groupname = ?, priority = ? WHERE groupname = ?'
  );
  $sth->execute($new->{'groupname'}, $new->{'priority'}, $old->{'groupname'})
    or die $dbh->errstr;
}

###
# class method to fetch groups/attributes from the sqlradius install on upgrade
###

sub _upgrade_exporttype {
  # do this only if the radius_attr table is empty
  local $FS::radius_attr::noexport_hack = 1;
  my $class = shift;
  return if qsearch('radius_attr', {});

  foreach my $self ($class->all_sqlradius) {
    my $error = $self->import_attrs;
    die "exportnum ".$self->exportnum.":\n$error\n" if $error;
  }
  return;
}

sub import_attrs {
  my $self = shift;
  my $dbh =  DBI->connect( map $self->option($_),
                                   qw( datasrc username password ) );
  unless ( $dbh ) {
    warn "Error connecting to RADIUS server: $DBI::errstr\n";
    return;
  }

  my $usergroup = $self->option('usergroup') || 'usergroup';
  my $error;
  warn "Importing RADIUS groups and attributes from ".$self->option('datasrc').
    "\n";

  # map out existing groups and attrs
  my %attrs_of;
  my %groupnum_of;
  foreach my $radius_group ( qsearch('radius_group', {}) ) {
    $attrs_of{$radius_group->groupname} = +{
      map { $_->attrname => $_ } $radius_group->radius_attr
    };
    $groupnum_of{$radius_group->groupname} = $radius_group->groupnum;
  }

  # get groupnames from radgroupcheck and radgroupreply
  my $sql = '
SELECT groupname, attribute, op, value, \'C\' FROM radgroupcheck
UNION
SELECT groupname, attribute, op, value, \'R\' FROM radgroupreply';
  my @fixes; # things that need to be changed on the radius db
  foreach my $row ( @{ $dbh->selectall_arrayref($sql) } ) {
    my ($groupname, $attrname, $op, $value, $attrtype) = @$row;
    warn "$groupname.$attrname\n";
    if ( !exists($groupnum_of{$groupname}) ) {
      my $radius_group = new FS::radius_group {
        'groupname' => $groupname,
        'priority'  => 1,
      };
      $error = $radius_group->insert;
      if ( $error ) {
        warn "error inserting group $groupname: $error";
        next;#don't continue trying to insert the attribute
      }
      $attrs_of{$groupname} = {};
      $groupnum_of{$groupname} = $radius_group->groupnum;
    }

    my $a = $attrs_of{$groupname};
    my $old = $a->{$attrname};
    my $new;

    if ( $attrtype eq 'R' ) {
      # Freeradius tolerates illegal operators in reply attributes.  We don't.
      if ( !grep ($_ eq $op, FS::radius_attr->ops('R')) ) {
        warn "$groupname.$attrname: changing $op to +=\n";
        # Make a note to change it in the db
        push @fixes, [
          'UPDATE radgroupreply SET op = \'+=\' WHERE groupname = ? AND attribute = ? AND op = ? AND VALUE = ?',
          $groupname, $attrname, $op, $value
        ];
        # and import it correctly.
        $op = '+=';
      }
    }

    if ( defined $old ) {
      # replace
      $new = new FS::radius_attr {
        $old->hash,
        'op'    => $op,
        'value' => $value,
      };
      $error = $new->replace($old);
      if ( $error ) {
        warn "error modifying attr $attrname: $error";
        next;
      }
    }
    else {
      $new = new FS::radius_attr {
        'groupnum' => $groupnum_of{$groupname},
        'attrname' => $attrname,
        'attrtype' => $attrtype,
        'op'       => $op,
        'value'    => $value,
      };
      $error = $new->insert;
      if ( $error ) {
        warn "error inserting attr $attrname: $error" if $error;
        next;
      }
    }
    $attrs_of{$groupname}->{$attrname} = $new;
  } #foreach $row

  foreach (@fixes) {
    my ($sql, @args) = @$_;
    my $sth = $dbh->prepare($sql);
    $sth->execute(@args) or warn $sth->errstr;
  }
    
  return;
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
    foreach qw( sqlradius sqlradius_withdomain radiator phone_sqlradius
                broadband_sqlradius );
  @part_export;
}

sub all_sqlradius_withaccounting {
  my $class = shift;
  grep { ! $_->option('ignore_accounting') } $class->all_sqlradius;
}

1;

