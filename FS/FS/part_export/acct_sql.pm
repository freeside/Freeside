package FS::part_export::acct_sql;

use vars qw(@ISA %info @saltset);
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
  'primary_key'        => { label => 'Database primary key' },
;

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

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Real-time export of accounts to SQL databases '.
                '(Postfix+Courier IMAP, others?)',
  'options'  => \%options,
  'nodomain' => '',
  'notes'    => <<END
Export accounts (svc_acct records) to SQL databases.  Written for
Postfix+Courier IMAP but intended to be generally useful for generic SQL
exports, eventually.

<BR><BR>In contrast to sqlmail, this is newer and less well tested, and
currently less flexible.  It is intended to export just svc_acct records only,
rather than a single export for svc_acct, svc_forward and svc_domain records,
to export in "default" formats rather than configure the MTA or POP/IMAP server
for a Freeside-specific schema, and possibly to be configured for different
mail server setups through some subclassing rather than options.

<BR><BR>Use these buttons for some useful presets:
<UL>
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
</UL>
END
);

sub _map {
  my $self = shift;
  map { /^\s*(\S+)\s*(\S+)\s*$/ } split("\n", $self->option('schema') );
}

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);

  my %map = $self->_map;

  my %record = map { my $value = $map{$_};
                     $_ => $svc_acct->$value();
                   } keys %map;

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
}

sub _export_delete {
  my ( $self, $svc_acct ) = (shift, shift);
  my %map = $self->_map;
  my $keymap = $map{$self->option('primary_key')};
  my $err_or_queue = $self->acct_sql_queue(
    $svc_acct->svcnum,
    'delete',
    $self->option('table'),
    $self->option('primary_key') => $svc_acct->$keymap(),
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

  $sth->execute( map $record{$_}, keys %record )
    or die "can't insert into $table table: ". $sth->errstr;

  $dbh->disconnect;
}

sub acct_sql_delete { #subroutine, not method
  my $dbh = acct_sql_connect(shift, shift, shift);
  my( $table, %record ) = @_;

  my $sth = $dbh->prepare(
    "DELETE FROM  $table WHERE ". join(' AND ', map "$_ = ? ", keys %record )
  ) or die $dbh->errstr;

  $sth->execute( map $record{$_}, keys %record )
    or die "can't delete from $table table: ". $sth->errstr;

  $dbh->disconnect;
}

sub acct_sql_connect {
  #my($datasrc, $username, $password) = @_;
  #DBI->connect($datasrc, $username, $password) or die $DBI::errstr;
  DBI->connect(@_) or die $DBI::errstr;
}

1;


