package FS::part_export::sqlradius;

use vars qw(@ISA);
use FS::Record qw( dbh );
use FS::part_export;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);

  foreach my $table (qw(reply check)) {
    my $method = "radius_$table";
    my %attrib = $svc_acct->$method();
    next unless keys %attrib;
    my $err_or_queue = $self->sqlradius_queue( $svc_acct->svcnum, 'insert',
      $table, $svc_acct->username, %attrib );
    return $err_or_queue unless ref($err_or_queue);
  }
  my @groups = $svc_acct->radius_groups;
  if ( @groups ) {
    my $err_or_queue = $self->sqlradius_queue(
      $svc_acct->svcnum, 'usergroup_insert',
      $svc_acct->username, @groups );
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
  if ( $old->username ne $new->username ) {
    my $err_or_queue = $self->sqlradius_queue( $new->svcnum, 'rename',
      $new->username, $old->username );
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
        $table, $new->username, %new );
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
        $table, $new->username, @del );
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

  # (sorta) false laziness with FS::svc_acct::replace
  my @oldgroups = @{$old->usergroup}; #uuuh
  my @newgroups = $new->radius_groups;
  my @delgroups = ();
  foreach my $oldgroup ( @oldgroups ) {
    if ( grep { $oldgroup eq $_ } @newgroups ) {
      @newgroups = grep { $oldgroup ne $_ } @newgroups;
      next;
    }
    push @delgroups, $oldgroup;
  }

  if ( @delgroups ) {
    my $err_or_queue = $self->sqlradius_queue( $new->svcnum, 'usergroup_delete',
      $new->username, @delgroups );
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

  if ( @newgroups ) {
    my $err_or_queue = $self->sqlradius_queue( $new->svcnum, 'usergroup_insert',
      $new->username, @newgroups );
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

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  my $err_or_queue = $self->sqlradius_queue( $svc_acct->svcnum, 'delete',
    $svc_acct->username );
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
        "INSERT INTO rad$table ( UserName, Attribute, Value ) ".
          "VALUES ( ?, ?, ? )"
      ) or die $dbh->errstr;
      $i_sth->execute( $username, $attribute, $attributes{$attribute} )
        or die $i_sth->errstr;

    }

  }
  $dbh->disconnect;
}

sub sqlradius_usergroup_insert { #subroutine, not method
  my $dbh = sqlradius_connect(shift, shift, shift);
  my( $username, @groups ) = @_;

  my $sth = $dbh->prepare( 
    "INSERT INTO usergroup ( UserName, GroupName ) VALUES ( ?, ? )"
  ) or die $dbh->errstr;
  foreach my $group ( @groups ) {
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

