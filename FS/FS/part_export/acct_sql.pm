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
;

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Real-time export of accounts to SQL databases '.
                '(Postfix+Courier IMAP, others?)',
  'options'  => \%options,
  'nodomain' => '',
  'notes'    => <<END
Export accounts (svc_acct records) to SQL databases.  Written for
Postfix+Courier IMAP but intended to be generally useful for generic SQL
exports eventually.

In contrast to sqlmail, this is newer and less well tested, and currently less
flexible.  It is intended to export just svc_acct records only, rather than a
single export for svc_acct, svc_forward and svc_domain records, and to 
be configured for different mail server setups through some subclassing
rather than options.
END
);

@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '.' , '/' );

#mapping needs to be configurable...
# export col => freeside col/method or callback
my %map = (
  'username' => 'email',
  'password' => '_password',
  'crypt'    => sub {
                  my $svc_acct = shift;
                  #false laziness w/shellcommands.pm
                  #eventually should check a "password-encoding" field
                  if ( length($svc_acct->_password) == 13
                       || $svc_acct->_password =~ /^\$(1|2a?)\$/ ) {
                    $svc_acct->_password;
                  } else {
                    crypt(
                      $svc_acct->_password,
                      $saltset[int(rand(64))].$saltset[int(rand(64))]
                    );
                  }

                },
  'name'     => 'finger',
  'maildir'  => sub { $_[0]->domain. '/maildirs/'. $_[0]->username. '/' },
  'domain'   => sub { shift->domain },
  'svcnum'   => 'svcnum',
);

my $table = 'mailbox'; #also needs to be configurable...

my $primary_key = 'username';

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);


  my %record = map { my $value = $map{$_};
                     $_ => ( ref($value)
                               ? &{$value}($svc_acct)
                               : $svc_acct->$value()
                           );
                   } keys %map;

  my $err_or_queue =
    $self->acct_sql_queue( $svc_acct->svcnum, 'insert', $table, %record );
  return $err_or_queue unless ref($err_or_queue);

  '';

}

sub _export_replace {
}

sub _export_delete {
  my ( $self, $svc_acct ) = (shift, shift);
  my $keymap = $map{$primary_key};
  my $err_or_queue = $self->acct_sql_queue(
    $svc_acct->svcnum,
    'delete',
    $table,
    $primary_key => ref($keymap) ? &{$keymap}($svc_acct) : $svc_acct->$keymap()
  );
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


