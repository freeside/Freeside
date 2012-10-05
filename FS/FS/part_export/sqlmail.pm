package FS::part_export::sqlmail;

use vars qw(@ISA %info);
use Tie::IxHash;
use Digest::MD5 qw(md5_hex);
use FS::Record qw(qsearchs);
use FS::part_export;
use FS::svc_domain;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'datasrc'            => { label => 'DBI data source' },
  'username'           => { label => 'Database username' },
  'password'           => { label => 'Database password' },
  'server_type'        => {
    label   => 'Server type',
    type    => 'select',
    options => [qw(dovecot_plain dovecot_crypt dovecot_digest_md5 courier_plain
                   courier_crypt)],
    default => ['dovecot_plain'], },
  'svc_acct_table'     => { label => 'User Table', default => 'user_acct' },
  'svc_forward_table'  => { label => 'Forward Table', default => 'forward' },
  'svc_domain_table'   => { label => 'Domain Table', default => 'domain' },
  'svc_acct_fields'    => { label => 'svc_acct Export Fields',
                            default => 'username _password domsvc svcnum' },
  'svc_forward_fields' => { label => 'svc_forward Export Fields',
                            default => 'srcsvc dstsvc dst' },
  'svc_domain_fields'  => { label => 'svc_domain Export Fields',
                            default => 'domain svcnum catchall' },
  'resolve_dstsvc'     => { label => q{Resolve svc_forward.dstsvc to an email address and store it in dst. (Doesn't require that you also export dstsvc.)},
                            type => 'checkbox' },
;

%info = (
  'svc'      => [qw( svc_acct svc_domain svc_forward )],
  'desc'     => 'Real-time export to SQL-backed mail server',
  'options'  => \%options,
  'nodomain' => '',
  'default_svc_class' => 'Email',
  'notes'    => <<'END'
Database schema can be made to work with Courier IMAP, Exim and Dovecot.
Others could work but are untested.  (more detailed description from
Kristian / fire2wire? )
END
);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc) = (shift, shift);
  # this is a svc_something.

  my $svcdb = $svc->cust_svc->part_svc->svcdb;
  my $export_table = $self->option($svcdb . '_table')
    or die('Export table not defined for svcdb: ' . $svcdb);
  my @export_fields = split(/\s+/, $self->option($svcdb . '_fields'));
  my $svchash = update_values($self, $svc, $svcdb);

  foreach my $key (keys(%$svchash)) {
    unless (grep { $key eq $_ } @export_fields) {
      delete $svchash->{$key};
    }
  }

  my $error = $self->sqlmail_queue( $svc->svcnum, 'insert',
    $self->option('server_type'), $export_table,
    (map { ($_, $svchash->{$_}); } keys(%$svchash)));
  return $error if $error;
  '';

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  my $svcdb = $new->cust_svc->part_svc->svcdb;
  my $export_table = $self->option($svcdb . '_table')
    or die('Export table not defined for svcdb: ' . $svcdb);
  my @export_fields = split(/\s+/, $self->option($svcdb . '_fields'));
  my $svchash = update_values($self, $new, $svcdb);

  foreach my $key (keys(%$svchash)) {
    unless (grep { $key eq $_ } @export_fields) {
      delete $svchash->{$key};
    }
  }

  my $error = $self->sqlmail_queue( $new->svcnum, 'replace',
    $old->svcnum, $self->option('server_type'), $export_table,
    (map { ($_, $svchash->{$_}); } keys(%$svchash)));
  return $error if $error;
  '';

}

sub _export_delete {
  my( $self, $svc ) = (shift, shift);

  my $svcdb = $svc->cust_svc->part_svc->svcdb;
  my $table = $self->option($svcdb . '_table')
    or die('Export table not defined for svcdb: ' . $svcdb);

  $self->sqlmail_queue( $svc->svcnum, 'delete', $table,
    $svc->svcnum );
}

sub sqlmail_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::sqlmail::sqlmail_$method",
  };
  $queue->insert(
    $self->option('datasrc'),
    $self->option('username'),
    $self->option('password'),
    @_,
  );
}

sub sqlmail_insert { #subroutine, not method
  my $dbh = sqlmail_connect(shift, shift, shift);
  my( $server_type, $table ) = (shift, shift);

  my %attrs = @_;

  map { $attrs{$_} = $attrs{$_} ? qq!'$attrs{$_}'! : 'NULL'; } keys(%attrs);
  my $query = sprintf("INSERT INTO %s (%s) values (%s)",
                      $table, join(",", keys(%attrs)),
                      join(',', values(%attrs)));

  $dbh->do($query) or die $dbh->errstr;
  $dbh->disconnect;

  '';
}

sub sqlmail_delete { #subroutine, not method
  my $dbh = sqlmail_connect(shift, shift, shift);
  my( $table, $svcnum ) = @_;

  $dbh->do("DELETE FROM $table WHERE svcnum = $svcnum") or die $dbh->errstr;
  $dbh->disconnect;

  '';
}

sub sqlmail_replace {
  my $dbh = sqlmail_connect(shift, shift, shift);
  my($oldsvcnum, $server_type, $table) = (shift, shift, shift);

  my %attrs = @_;
  map { $attrs{$_} = $attrs{$_} ? qq!'$attrs{$_}'! : 'NULL'; } keys(%attrs);

  my $query = "SELECT COUNT(*) FROM $table WHERE svcnum = $oldsvcnum";
  my $result = $dbh->selectrow_arrayref($query) or die $dbh->errstr;
  
  if (@$result[0] == 0) {
    $query = sprintf("INSERT INTO %s (%s) values (%s)",
                     $table, join(",", keys(%attrs)),
                     join(',', values(%attrs)));
    $dbh->do($query) or die $dbh->errstr;
  } else {
    $query = sprintf('UPDATE %s SET %s WHERE svcnum = %s',
                     $table, join(', ', map {"$_ = $attrs{$_}"} keys(%attrs)),
                     $oldsvcnum);
    $dbh->do($query) or die $dbh->errstr;
  }

  $dbh->disconnect;

  '';
}

sub sqlmail_connect {
  DBI->connect(@_) or die $DBI::errstr;
}

sub update_values {

  # Update records to conform to a particular server_type.

  my ($self, $svc, $svcdb) = (shift,shift,shift);
  my $svchash = { %{$svc->hashref} } or return ''; # We need a copy.

  if ($svcdb eq 'svc_acct') {
    if ($self->option('server_type') eq 'courier_crypt') {
      my $salt = join '', ('.', '/', 0..9,'A'..'Z', 'a'..'z')[rand 64, rand 64];
      $svchash->{_password} = crypt($svchash->{_password}, $salt);

    } elsif ($self->option('server_type') eq 'dovecot_plain') {
      $svchash->{_password} = '{PLAIN}' . $svchash->{_password};
      
    } elsif ($self->option('server_type') eq 'dovecot_crypt') {
      my $salt = join '', ('.', '/', 0..9,'A'..'Z', 'a'..'z')[rand 64, rand 64];
      $svchash->{_password} = '{CRYPT}' . crypt($svchash->{_password}, $salt);

    } elsif ($self->option('server_type') eq 'dovecot_digest_md5') {
      my $svc_domain = qsearchs('svc_domain', { svcnum => $svc->domsvc });
      die('Unable to lookup svc_domain with domsvc: ' . $svc->domsvc)
        unless ($svc_domain);

      my $domain = $svc_domain->domain;
      my $md5hash = '{DIGEST-MD5}' . md5_hex(join(':', $svchash->{username},
                                             $domain, $svchash->{_password}));
      $svchash->{_password} = $md5hash;
    }
  } elsif ($svcdb eq 'svc_forward') {
    if ($self->option('resolve_dstsvc') && $svc->dstsvc_acct) {
      $svchash->{dst} = $svc->dstsvc_acct->username . '@' .
                        $svc->dstsvc_acct->svc_domain->domain;
    }
  }

  return($svchash);

}

1;

