package FS::part_export::acct_sql;

use vars qw(@ISA %info);
use Tie::IxHash;
#use Digest::MD5 qw(md5_hex);
use FS::Record; #qw(qsearchs);
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'datasrc'            => { label => 'DBI data source' },
  'username'           => { label => 'Database username' },
  'password'           => { label => 'Database password' },
  'table'              => { label => 'Database table' },
  'schema'             => { label =>
                              'Database schema mapping to Freeside methods.',
                            type  => 'textarea',
                          },
  'static'             => { label =>
                              'Database schema mapping to static values.',
                            type  => 'textarea',
                          },
  'primary_key'        => { label => 'Database primary key' },
  'crypt'              => { label => 'Password encryption',
                            type=>'select', options=>[qw(crypt md5 sha1_base64)],
                            default=>'crypt',
                          },
;

tie my %vpopmail_map, 'Tie::IxHash',
  'pw_name'   => 'username',
  'pw_domain' => 'domain',
  'pw_passwd' => 'crypt_password',
  'pw_uid'    => 'uid',
  'pw_gid'    => 'gid',
  'pw_gecos'  => 'finger',
  'pw_dir'    => 'dir',
  #'pw_shell'  => 'shell',
  'pw_shell'  => 'quota',
;
my $vpopmail_map = join('\n', map "$_ $vpopmail_map{$_}", keys %vpopmail_map );

tie my %postfix_courierimap_mailbox_map, 'Tie::IxHash',
  'username' => 'email',
  'password' => '_password',
  'crypt'    => 'crypt_password',
  'name'     => 'finger',
  'maildir'  => 'virtual_maildir',
  'domain'   => 'domain',
  'svcnum'   => 'svcnum',
;
my $postfix_courierimap_mailbox_map =
  join('\n', map "$_ $postfix_courierimap_mailbox_map{$_}",
                 keys %postfix_courierimap_mailbox_map      );

tie my %postfix_courierimap_alias_map, 'Tie::IxHash',
  'address' => 'email',
  'goto'    => 'email',
  'domain'  => 'domain',
  'svcnum'  => 'svcnum',
;
my $postfix_courierimap_alias_map =
  join('\n', map "$_ $postfix_courierimap_alias_map{$_}",
                 keys %postfix_courierimap_alias_map      );

tie my %postfix_native_mailbox_map, 'Tie::IxHash',
  'userid'   => 'email',
  'uid'      => 'uid',
  'gid'      => 'gid',
  'password' => 'ldap_password',
  'mail'     => 'domain_slash_username',
;
my $postfix_native_mailbox_map =
  join('\n', map "$_ $postfix_native_mailbox_map{$_}",
                 keys %postfix_native_mailbox_map      );

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Real-time export of accounts to SQL databases '.
                '(vpopmail, Postfix+Courier IMAP, others?)',
  'options'  => \%options,
  'nodomain' => '',
  'notes'    => <<END
Export accounts (svc_acct records) to SQL databases.  Currently has default
configurations for vpopmail and Postfix+Courier IMAP but intended to be
configurable for other schemas as well.

<BR><BR>In contrast to sqlmail, this is intended to export just svc_acct
records only, rather than a single export for svc_acct, svc_forward and
svc_domain records, to export in "default" database schemas rather than
configure the MTA or POP/IMAP server for a Freeside-specific schema, and
to be configured for different mail server setups.

<BR><BR>Use these buttons for some useful presets:
<UL>
  <li><INPUT TYPE="button" VALUE="vpopmail" onClick='
    this.form.table.value = "vpopmail";
    this.form.schema.value = "$vpopmail_map";
    this.form.primary_key.value = "pw_name, pw_domain";
  '>
  <LI><INPUT TYPE="button" VALUE="postfix_courierimap_mailbox" onClick='
    this.form.table.value = "mailbox";
    this.form.schema.value = "$postfix_courierimap_mailbox_map";
    this.form.primary_key.value = "username";
  '>
  <LI><INPUT TYPE="button" VALUE="postfix_courierimap_alias" onClick='
    this.form.table.value = "alias";
    this.form.schema.value = "$postfix_courierimap_alias_map";
    this.form.primary_key.value = "address";
  '>
  <LI><INPUT TYPE="button" VALUE="postfix_native_mailbox" onClick='
    this.form.table.value = "users";
    this.form.schema.value = "$postfix_native_mailbox_map";
    this.form.primary_key.value = "userid";
  '>
</UL>
END
);

sub _schema_map { shift->_map('schema'); }
sub _static_map { shift->_map('static'); }

sub _map {
  my $self = shift;
  map { /^\s*(\S+)\s*(\S+)\s*$/ } split("\n", $self->option(shift) );
}

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);

  my %schema = $self->_schema_map;
  my %static = $self->_static_map;

  my %record = (

    ( map { $_ => $static{$_} } keys %static ),
  
    ( map { my $value = $schema{$_};
            my @arg = ();
            push @arg, $self->option('crypt')
              if $value eq 'crypt_password' && $self->option('crypt');
            $_ => $svc_acct->$value(@arg);
          } keys %schema
    ),

  );

  my $err_or_queue =
    $self->acct_sql_queue(
      $svc_acct->svcnum,
      'insert',
      $self->option('table'),
      %record
    );
  return $err_or_queue unless ref($err_or_queue);

  '';

}

sub _export_replace {
  my($self, $new, $old) = (shift, shift, shift);

  my %schema = $self->_schema_map;
  my %static = $self->_static_map;

  my @primary_key = ();
  if ( $self->option('primary_key') =~ /,/ ) {
    foreach my $key ( split(/\s*,\s*/, $self->option('primary_key') ) ) {
      my $keymap = $schema{$key};
      push @primary_key, $old->$keymap();
    }
  } else {
    my $keymap = $schema{$self->option('primary_key')};
    push @primary_key, $old->$keymap();
  }

  my %record = (

    ( map { $_ => $static{$_} } keys %static ),
  
    ( map { my $value = $schema{$_};
            my @arg = ();
            push @arg, $self->option('crypt')
              if $value eq 'crypt_password' && $self->option('crypt');
            $_ => $new->$value(@arg);
          } keys %schema
    ),

  );

  my $err_or_queue = $self->acct_sql_queue(
    $new->svcnum,
    'replace',
    $self->option('table'),
    $self->option('primary_key'), @primary_key, 
    %record,
  );
  return $err_or_queue unless ref($err_or_queue);
  '';
}

sub _export_delete {
  my ( $self, $svc_acct ) = (shift, shift);

  my %schema = $self->_schema_map;

  my %primary_key = ();
  if ( $self->option('primary_key') =~ /,/ ) {
    foreach my $key ( split(/\s*,\s*/, $self->option('primary_key') ) ) {
      my $keymap = $schema{$key};
      $primary_key{ $key } = $svc_acct->$keymap();
    }
  } else {
    my $keymap = $schema{$self->option('primary_key')};
    $primary_key{ $self->option('primary_key') } = $svc_acct->$keymap(),
  }

  my $err_or_queue = $self->acct_sql_queue(
    $svc_acct->svcnum,
    'delete',
    $self->option('table'),
    %primary_key,
    #$self->option('primary_key') => $svc_acct->$keymap(),
  );
  return $err_or_queue unless ref($err_or_queue);
  '';
}

sub acct_sql_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::acct_sql::acct_sql_$method",
  };
  $queue->insert(
    $self->option('datasrc'),
    $self->option('username'),
    $self->option('password'),
    @_,
  ) or $queue;
}

sub acct_sql_insert { #subroutine, not method
  my $dbh = acct_sql_connect(shift, shift, shift);
  my( $table, %record ) = @_;

  my $sth = $dbh->prepare(
    "INSERT INTO $table ( ". join(", ", keys %record).
    " ) VALUES ( ". join(", ", map '?', keys %record ). " )"
  ) or die $dbh->errstr;

  $sth->execute( values(%record) )
    or die "can't insert into $table table: ". $sth->errstr;

  $dbh->disconnect;
}

sub acct_sql_delete { #subroutine, not method
  my $dbh = acct_sql_connect(shift, shift, shift);
  my( $table, %record ) = @_;

  my $sth = $dbh->prepare(
    "DELETE FROM $table WHERE ". join(' AND ', map "$_ = ? ", keys %record )
  ) or die $dbh->errstr;

  $sth->execute( map $record{$_}, keys %record )
    or die "can't delete from $table table: ". $sth->errstr;

  $dbh->disconnect;
}

sub acct_sql_replace { #subroutine, not method
  my $dbh = acct_sql_connect(shift, shift, shift);

  my( $table, $pkey ) = ( shift, shift );

  my %primary_key = ();
  if ( $pkey =~ /,/ ) {
    foreach my $key ( split(/\s*,\s*/, $pkey ) ) {
      $primary_key{$key} = shift;
    }
  } else {
    $primary_key{$pkey} = shift;
  }

  my %record = @_;

  my $sth = $dbh->prepare(
    "UPDATE $table".
    ' SET '.   join(', ',    map "$_ = ?", keys %record      ).
    ' WHERE '. join(' AND ', map "$_ = ?", keys %primary_key )
  ) or die $dbh->errstr;

  $sth->execute( values(%record), values(%primary_key) );

  $dbh->disconnect;
}

sub acct_sql_connect {
  #my($datasrc, $username, $password) = @_;
  #DBI->connect($datasrc, $username, $password) or die $DBI::errstr;
  DBI->connect(@_) or die $DBI::errstr;
}

1;

