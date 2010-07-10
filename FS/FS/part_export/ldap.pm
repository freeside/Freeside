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
  'key_attrib' => { label=>'Key attribute name',
                    default=>'uid' },
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

sub svc_context_eval {
  # This should possibly be in svc_Common?
  # Except the only places we use it are here and in shellcommands,
  # and it's not even the same version.
  my $svc_acct = shift;
  no strict 'refs';
  ${$_} = $svc_acct->getfield($_) foreach $svc_acct->fields;
  ${$_} = $svc_acct->$_() foreach qw( domain ldap_password );
  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
  if ( $cust_pkg ) {
    my $cust_main = $cust_pkg->cust_main;
    ${$_} = $cust_main->getfield($_) foreach qw(first last);
  }
  # DEPRECATED, probably fails for non-plain password encoding
  $crypt_password = ''; #surpress "used only once" warnings
  $crypt_password = '{crypt}'. crypt( $svc_acct->_password,
                             $saltset[int(rand(64))].$saltset[int(rand(64))] );

  return map { eval(qq("$_")) } @_ ;
}

sub key_attrib {
  my $self = shift;
  return $self->option('key_attrib') if $self->option('key_attrib');
  # otherwise, guess that it's the one that's set to $username
  foreach ( split("\n",$self->option('attributes')) ) {
    /^\s*(\w+)\s+\$username\s*$/ && return $1;
  }
  # can't recover from that, but we can fail in a more obvious way 
  # than the old code did...
  die "no key_attrib set in LDAP export\n";
}

sub ldap_attrib {
  # Convert the svc_acct to its LDAP attribute set.
  my($self, $svc_acct) = (shift, shift);
  my %attrib = map    { /^\s*(\w+)\s+(.*\S)\s*$/;
                        ( $1 => $2 ); }
                 grep { /^\s*(\w+)\s+(.*\S)\s*$/ }
                   split("\n", $self->option('attributes'));

  my @vals = svc_context_eval($svc_acct, values(%attrib));
  @attrib{keys(%attrib)} = @vals;

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
  return %attrib;
}

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);

  my $err_or_queue = $self->ldap_queue( 
    $svc_acct->svcnum, 
    'insert',
    $self->key_attrib,
    $self->ldap_attrib($svc_acct),
  );
  return $err_or_queue unless ref($err_or_queue);

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

  # the Lazy way: nuke the entry and recreate it.
  # any reason this shouldn't work?  Freeside _has_ to have 
  # write access to these entries and their parent DN.
  my $key = $self->key_attrib;
  my %attrib = $self->ldap_attrib($old);
  my $err_or_queue = $self->ldap_queue( 
    $old->svcnum,
    'delete', 
    $key,
    $attrib{$key}
  );
  if( !ref($err_or_queue) ) {
    $dbh->rollback if $oldAutoCommit;
    return $err_or_queue;
  }
  $jobnum = $err_or_queue->jobnum;
  $err_or_queue = $self->ldap_queue( 
    $new->svcnum, 
    'insert',
    $key,
    $self->ldap_attrib($new)
  );
  if( !ref($err_or_queue) ) {
    $dbh->rollback if $oldAutoCommit;
    return $err_or_queue;
  }
  $err_or_queue = $err_or_queue->depend_insert($jobnum);
  if( $err_or_queue ) {
    $dbh->rollback if $oldAutoCommit;
    return $err_or_queue;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);

  my $key = $self->key_attrib;
  my ( $val ) = map { /^\s*$key\s+(.*\S)\s*$/ ? $1 : () }
                    split("\n", $self->option('attributes'));
  ( $val ) = svc_context_eval($svc_acct, $val);
  my $err_or_queue = $self->ldap_queue( $svc_acct->svcnum, 'delete',
    $key, $val );
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
  my( $userdn, $key_attrib, %attrib ) = @_;

  $userdn = "$key_attrib=$attrib{$key_attrib}, $userdn";
  #icky hack, but should be unsurprising to the LDAPers
  foreach my $key ( grep { $attrib{$_} =~ /,/ } keys %attrib ) {
    $attrib{$key} = [ split(/,/, $attrib{$key}) ]; 
  }

  my $status = $ldap->add( $userdn, attrs => [ %attrib ] );
  die 'LDAP error: '. $status->error. "\n" if $status->is_error;

  $ldap->unbind;
}

sub ldap_delete {
  my $ldap = ldap_connect(shift, shift, shift);

  my $entry = ldap_fetch($ldap, @_);
  if($entry) {
    my $status = $ldap->delete($entry);
    die 'LDAP error: '.$status->error."\n" if $status->is_error;
  }
  $ldap->unbind;
  # should failing to find the entry be fatal?
  # if it is, it will block unprovisioning the service, which is a pain.
}

sub ldap_fetch {
  # avoid needless duplication in delete and modify
  my( $ldap, $userdn, %key_data ) = @_;
  my $filter = join('', map { "($_=$key_data{$_})" } keys(%key_data));

  my $status = $ldap->search( base => $userdn,
                              scope => 'one', 
                              filter => $filter );
  die 'LDAP error: '.$status->error."\n" if $status->is_error;
  my ($entry) = $status->entries;
  warn "Entry '$filter' not found in LDAP\n" if !$entry;
  return $entry;
}

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

