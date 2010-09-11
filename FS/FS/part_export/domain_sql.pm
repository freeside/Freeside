package FS::part_export::domain_sql;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

#quite a bit of false laziness w/acct_sql - some stuff should be generalized
#out to a "dababase base class"

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
;

tie my %postfix_transport_map, 'Tie::IxHash', 
  'domain' => 'domain'
;
my $postfix_transport_map = 
  join('\n', map "$_ $postfix_transport_map{$_}",
                 keys %postfix_transport_map      );
tie my %postfix_transport_static, 'Tie::IxHash',
  'transport' => 'virtual:',
;
my $postfix_transport_static = 
  join('\n', map "$_ $postfix_transport_static{$_}",
                 keys %postfix_transport_static      );

%info  = (
  'svc'     => 'svc_domain',
  'desc'    => 'Real time export of domains to SQL databases '.
               '(postfix, others?)',
  'options' => \%options,
  'notes'   => <<END
Export domains (svc_domain records) to SQL databases.  Currently this is a
simple export with a default for Postfix, but it can be extended for other
uses.

<BR><BR>Use these buttons for useful presets:
<UL>
  <LI><INPUT TYPE="button" VALUE="postfix_transport" onClick='
    this.form.table.value = "transport";
    this.form.schema.value = "$postfix_transport_map";
    this.form.static.value = "$postfix_transport_static";
    this.form.primary_key.value = "domain";
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

sub _export_insert {
  my($self, $svc_domain) = (shift, shift);

  my %schema = $self->_schema_map;
  my %static = $self->_static_map;

  my %record = ( ( map { $_ => $static{$_}       } keys %static ),
                 ( map { my $method = $schema{$_};
	               $_ => $svc_domain->$method();
		       }
		       keys %schema
		 )
	       );

  my $err_or_queue = 
    $self->domain_sql_queue(
      $svc_domain->svcnum,
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
  #my %map = (%schema, %static);

  my @primary_key = ();
  if ( $self->option('primary_key') =~ /,/ ) {
    foreach my $key ( split(/\s*,\s*/, $self->option('primary_key') ) ) {
      my $keymap = $schema{$key};
      push @primary_key, $old->$keymap();
    }
  } else {
    my %map = (%schema, %static);
    my $keymap = $map{$self->option('primary_key')};
    push @primary_key, $old->$keymap();
  }

  my %record = ( ( map { $_ => $static{$_}       } keys %static ),
                 ( map { my $method = $schema{$_};
	                 $_ => $new->$method();
	               }
		       keys %schema
		 )
	       );

  my $err_or_queue = $self->domain_sql_queue(
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
  my ( $self, $svc_domain ) = (shift, shift);

  my %schema = $self->_schema_map;
  my %static = $self->_static_map;
  my %map = (%schema, %static);

  my %primary_key = ();
  if ( $self->option('primary_key') =~ /,/ ) {
    foreach my $key ( split(/\s*,\s*/, $self->option('primary_key') ) ) {
      my $keymap = $map{$key};
      $primary_key{ $key } = $svc_domain->$keymap();
    }
  } else {
    my $keymap = $map{$self->option('primary_key')};
    $primary_key{ $self->option('primary_key') } = $svc_domain->$keymap(),
  }

  my $err_or_queue = $self->domain_sql_queue(
    $svc_domain->svcnum,
    'delete',
    $self->option('table'),
    %primary_key,
    #$self->option('primary_key') => $svc_domain->$keymap(),
  );
  return $err_or_queue unless ref($err_or_queue);
  '';
}

sub domain_sql_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::domain_sql::domain_sql_$method",
  };
  $queue->insert(
    $self->option('datasrc'),
    $self->option('username'),
    $self->option('password'),
    @_,
  ) or $queue;
}

sub domain_sql_insert { #subroutine, not method
  my $dbh = domain_sql_connect(shift, shift, shift);
  my( $table, %record ) = @_;

  my $sth = $dbh->prepare(
    "INSERT INTO $table ( ". join(", ", keys %record).
    " ) VALUES ( ". join(", ", map '?', keys %record ). " )"
  ) or die $dbh->errstr;

  $sth->execute( values(%record) )
    or die "can't insert into $table table: ". $sth->errstr;

  $dbh->disconnect;
}

sub domain_sql_delete { #subroutine, not method
  my $dbh = domain_sql_connect(shift, shift, shift);
  my( $table, %record ) = @_;

  my $sth = $dbh->prepare(
    "DELETE FROM $table WHERE ". join(' AND ', map "$_ = ? ", keys %record )
  ) or die $dbh->errstr;

  $sth->execute( map $record{$_}, keys %record )
    or die "can't delete from $table table: ". $sth->errstr;

  $dbh->disconnect;
}

sub domain_sql_replace { #subroutine, not method
  my $dbh = domain_sql_connect(shift, shift, shift);

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

sub domain_sql_connect {
  #my($datasrc, $username, $password) = @_;
  #DBI->connect($datasrc, $username, $password) or die $DBI::errstr;
  DBI->connect(@_) or die $DBI::errstr;
}

1;

