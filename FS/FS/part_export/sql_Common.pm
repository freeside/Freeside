package FS::part_export::sql_Common;
use base qw( FS::part_export );

use strict;
use Tie::IxHash;

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

sub sql_options {
  \%options;
}
sub _schema_map { shift->_map('schema'); }
sub _static_map { shift->_map('static'); }

sub _map {
  my $self = shift;
  map { /^\s*(\S+)\s*(\S+)\s*$/ } split("\n", $self->option(shift) );
}

sub _map_arg_callback {
  ();
}

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_x) = (shift, shift);

  my %schema = $self->_schema_map;
  my %static = $self->_static_map;

  my %record = (

    ( map { $_ => $static{$_} } keys %static ),
  
    ( map { my $value = $schema{$_};
            my @arg = $self->_map_arg_callback($value);
            $_ => $svc_x->$value(@arg);
          } keys %schema
    ),

  );

  my $err_or_queue =
    $self->sql_Common_queue(
      $svc_x->svcnum,
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
            my @arg = $self->_map_arg_callback($value);
            $_ => $new->$value(@arg);
          } keys %schema
    ),

  );

  my $err_or_queue = $self->sql_Common_queue(
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
  my ( $self, $svc_x ) = (shift, shift);

  my %schema = $self->_schema_map;

  my %primary_key = ();
  if ( $self->option('primary_key') =~ /,/ ) {
    foreach my $key ( split(/\s*,\s*/, $self->option('primary_key') ) ) {
      my $keymap = $schema{$key};
      $primary_key{ $key } = $svc_x->$keymap();
    }
  } else {
    my $keymap = $schema{$self->option('primary_key')};
    $primary_key{ $self->option('primary_key') } = $svc_x->$keymap(),
  }

  my $err_or_queue = $self->sql_Common_queue(
    $svc_x->svcnum,
    'delete',
    $self->option('table'),
    %primary_key,
    #$self->option('primary_key') => $svc_x->$keymap(),
  );
  return $err_or_queue unless ref($err_or_queue);
  '';
}

sub sql_Common_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::sql_Common::sql_Common_$method",
  };
  $queue->insert(
    $self->option('datasrc'),
    $self->option('username'),
    $self->option('password'),
    @_,
  ) or $queue;
}

sub sql_Common_insert { #subroutine, not method
  my $dbh = sql_Common_connect(shift, shift, shift);
  my( $table, %record ) = @_;

  my $sth = $dbh->prepare(
    "INSERT INTO $table ( ". join(", ", keys %record).
    " ) VALUES ( ". join(", ", map '?', keys %record ). " )"
  ) or die $dbh->errstr;

  $sth->execute( values(%record) )
    or die "can't insert into $table table: ". $sth->errstr;

  $dbh->disconnect;
}

sub sql_Common_delete { #subroutine, not method
  my $dbh = sql_Common_connect(shift, shift, shift);
  my( $table, %record ) = @_;

  my $sth = $dbh->prepare(
    "DELETE FROM $table WHERE ". join(' AND ', map "$_ = ? ", keys %record )
  ) or die $dbh->errstr;

  $sth->execute( map $record{$_}, keys %record )
    or die "can't delete from $table table: ". $sth->errstr;

  $dbh->disconnect;
}

sub sql_Common_replace { #subroutine, not method
  my $dbh = sql_Common_connect(shift, shift, shift);

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

sub sql_Common_connect {
  #my($datasrc, $username, $password) = @_;
  #DBI->connect($datasrc, $username, $password) or die $DBI::errstr;
  DBI->connect(@_) or die $DBI::errstr;
}

1;

