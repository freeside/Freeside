package FS::part_export::ldap;

use vars qw(@ISA %info @saltset);
use Tie::IxHash;
use FS::Record qw( dbh );
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'dn'         => { label=>'Root DN' },
  'password'   => { label=>'Root DN password' },
  'userdn'     => { label=>'User DN' },
  'attributes' => { label=>'Attributes',
                    type=>'textarea',
                    default=>join("\n",
                      'uid $username',
                      'mail $username\@$domain',
                      'uidno $uid',
                      'gidno $gid',
                      'cn $first',
                      'sn $last',
                      'mailquota $quota',
                      'vmail',
                      'location',
                      'mailtag',
                      'mailhost',
                      'mailmessagestore $dir',
                      'userpassword $crypt_password',
                      'hint',
                      'answer $sec_phrase',
                      'objectclass top,person,inetOrgPerson',
                    ),
                  },
  'radius'     => { label=>'Export RADIUS attributes', type=>'checkbox', },
;

%info = (
  'svc'     => 'svc_acct',
  'desc'    => 'Real-time export to LDAP',
  'options' => \%options,
  'notes'   => <<'END'
Real-time export to arbitrary LDAP attributes.  Requires installation of
<a href="http://search.cpan.org/dist/Net-LDAP">Net::LDAP</a> from CPAN.
END
);

@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '.' , '/' );

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);

  #false laziness w/shellcommands.pm
  {
    no strict 'refs';
    ${$_} = $svc_acct->getfield($_) foreach $svc_acct->fields;
    ${$_} = $svc_acct->$_() foreach qw( domain );
    my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
    if ( $cust_pkg ) {
      my $cust_main = $cust_pkg->cust_main;
      ${$_} = $cust_main->getfield($_) foreach qw(first last);
    }
  }
  $crypt_password = ''; #surpress "used only once" warnings
  $crypt_password = '{crypt}'. crypt( $svc_acct->_password,
                             $saltset[int(rand(64))].$saltset[int(rand(64))] );

  my $username_attrib;
  my %attrib = map    { /^\s*(\w+)\s+(.*\S)\s*$/;
                        $username_attrib = $1 if $2 eq '$username';
                        ( $1 => eval(qq("$2")) );                   }
                 grep { /^\s*(\w+)\s+(.*\S)\s*$/ }
                   split("\n", $self->option('attributes'));

  if ( $self->option('radius') ) {
    foreach my $table (qw(reply check)) {
      my $method = "radius_$table";
      my %radius = $svc_acct->$method();
      foreach my $radius ( keys %radius ) {
        ( my $ldap = $radius ) =~ s/\-//g;
        $attrib{$ldap} = $radius{$radius};
      }
    }
  }

  my $err_or_queue = $self->ldap_queue( $svc_acct->svcnum, 'insert',
    #$svc_acct->username,
    $username_attrib,
    %attrib );
  return $err_or_queue unless ref($err_or_queue);

  #groups with LDAP?
  #my @groups = $svc_acct->radius_groups;
  #if ( @groups ) {
  #  my $err_or_queue = $self->ldap_queue(
  #    $svc_acct->svcnum, 'usergroup_insert',
  #    $svc_acct->username, @groups );
  #  return $err_or_queue unless ref($err_or_queue);
  #}

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

  return "can't (yet?) change username with ldap"
    if $old->username ne $new->username;

  return "ldap replace unimplemented";

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $jobnum = '';
  #if ( $old->username ne $new->username ) {
  #  my $err_or_queue = $self->ldap_queue( $new->svcnum, 'rename',
  #    $new->username, $old->username );
  #  unless ( ref($err_or_queue) ) {
  #    $dbh->rollback if $oldAutoCommit;
  #    return $err_or_queue;
  #  }
  #  $jobnum = $err_or_queue->jobnum;
  #}

  foreach my $table (qw(reply check)) {
    my $method = "radius_$table";
    my %new = $new->$method();
    my %old = $old->$method();
    if ( grep { !exists $old{$_} #new attributes
                || $new{$_} ne $old{$_} #changed
              } keys %new
    ) {
      my $err_or_queue = $self->ldap_queue( $new->svcnum, 'insert',
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
      my $err_or_queue = $self->ldap_queue( $new->svcnum, 'attrib_delete',
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
    my $err_or_queue = $self->ldap_queue( $new->svcnum, 'usergroup_delete',
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
    my $err_or_queue = $self->ldap_queue( $new->svcnum, 'usergroup_insert',
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
  return "ldap delete unimplemented";
  my $err_or_queue = $self->ldap_queue( $svc_acct->svcnum, 'delete',
    $svc_acct->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub ldap_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::ldap::ldap_$method",
  };
  $queue->insert(
    $self->machine,
    $self->option('dn'),
    $self->option('password'),
    $self->option('userdn'),
    @_,
  ) or $queue;
}

sub ldap_insert { #subroutine, not method
  my $ldap = ldap_connect(shift, shift, shift);
  my( $userdn, $username_attrib, %attrib ) = @_;

  $userdn = "$username_attrib=$attrib{$username_attrib}, $userdn"
    if $username_attrib;
  #icky hack, but should be unsurprising to the LDAPers
  foreach my $key ( grep { $attrib{$_} =~ /,/ } keys %attrib ) {
    $attrib{$key} = [ split(/,/, $attrib{$key}) ]; 
  }

  my $status = $ldap->add( $userdn, attrs => [ %attrib ] );
  die 'LDAP error: '. $status->error. "\n" if $status->is_error;

  $ldap->unbind;
}

#sub ldap_delete { #subroutine, not method
#  my $dbh = ldap_connect(shift, shift, shift);
#  my $username = shift;
#
#  foreach my $table (qw( radcheck radreply usergroup )) {
#    my $sth = $dbh->prepare( "DELETE FROM $table WHERE UserName = ?" );
#    $sth->execute($username)
#      or die "can't delete from $table table: ". $sth->errstr;
#  }
#  $dbh->disconnect;
#}

sub ldap_connect {
  my( $machine, $dn, $password ) = @_;
  my %bind_options;
  $bind_options{password} = $password if length($password);

  eval "use Net::LDAP";
  die $@ if $@;

  my $ldap = Net::LDAP->new($machine) or die $@;
  my $status = $ldap->bind( $dn, %bind_options );
  die 'LDAP error: '. $status->error. "\n" if $status->is_error;

  $ldap;
}

1;

