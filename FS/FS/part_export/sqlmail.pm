package FS::part_export::sqlmail;

use vars qw(@ISA %fs_mail_table %fields);
use FS::part_export;

@ISA = qw(FS::part_export);

%fs_mail_table = ( svc_acct => 'user',
                   svc_domain => 'domain' );

# fields that need to be copied into the fs_mail tables
$fields{user} = [qw(username _password finger domsvc svcnum )];
$fields{domain} = [qw(domain svcnum catchall )];

sub rebless { shift; }

sub _export_insert {
  my($self, $svc) = (shift, shift);
  # this is a svc_something.

  my $table = $fs_mail_table{$svc->cust_svc->part_svc->svcdb};
  my @attrib = map {$svc->$_} @{$fields{$table}};
  my $error = $self->sqlmail_queue( $svc->svcnum, 'insert',
      $table, @attrib );
  return $error if $error;
  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  my $table = $fs_mail_table{$new->cust_svc->part_svc->svcdb};

  my @old = ($old->svcnum, 'delete', $table, $old->svcnum);
  my @narf = map {$new->$_} @{$fields{$table}};
  $self->sqlmail_queue($new->svcnum, 'replace', $table, 
      $new->svcnum, @narf);

  return $error if $error;
  '';
}

sub _export_delete {
  my( $self, $svc ) = (shift, shift);
  my $table = $fs_mail_table{$new->cust_svc->part_svc->svcdb};
  $self->sqlmail_queue( $svc->svcnum, 'delete', $table,
    $svc->svcnum );
}

sub sqlmail_queue {
  my( $self, $svcnum, $method, $table ) = (shift, shift, shift);
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
  my( $table, @attrib ) = @_;

  my $sth = $dbh->prepare(
    "INSERT INTO $table (" . join (',', @{$fields{$table}}) .
    ") VALUES ('" . join ("','", @attrib) . "')"
  ) or die $dbh->errstr;
  $sth->execute() or die $sth->errstr;

  $dbh->disconnect;
}

sub sqlmail_delete { #subroutine, not method
  my $dbh = sqlmail_connect(shift, shift, shift);
  my( $table, $svcnum ) = @_;

  my $sth = $dbh->prepare(
    "DELETE FROM $table WHERE svcnum = $svcnum"
  ) or die $dbh->errstr;
  $sth->execute() or die $sth->errstr;

  $dbh->disconnect;
}

sub sqlmail_replace {
  my $dbh = sqlmail_connect(shift, shift, shift);
  my( $table, $svcnum, @attrib ) = @_;

  my %data;
  @data{@{$fields{$table}}} = @attrib;

  my $sth = $dbh->prepare(
    "UPDATE $table SET " .
    ( join ',',  map {$_ . "='" . $data{$_} . "'"} keys(%data) ) .
    " WHERE svcnum = $svcnum"
    ) or die $dbh->errstr;
  $sth->execute() or die $sth->errstr;

  $dbh->disconnect;
}

sub sqlmail_connect {
  #my($datasrc, $username, $password) = @_;
  #DBI->connect($datasrc, $username, $password) or die $DBI::errstr;
  DBI->connect(@_) or die $DBI::errstr;
}

