package FS::cdr::Import;

use strict;
use Date::Format 'time2str';
use FS::UID qw(adminsuidsetup dbh);
use FS::cdr;
use DBI;
use Getopt::Std;

use vars qw( $DEBUG );
$DEBUG = 0;

=head1 NAME

FS::cdr::Import - CDR importing

=head1 SYNOPSIS

  use FS::cdr::Import;

  FS::cdr::Import->dbi_import(
    'dbd'                => 'Pg', #mysql, Sybase, etc.
    'database'           => 'DATABASE_NAME',
    'table'              => 'TABLE_NAME',,
    'status_table'       => 'STATUS_TABLE_NAME', # if using a table rather than field in main table
    'primary_key'        => 'BILLING_ID',
    'primary_key_info'   => 'BIGINT', # defaults to bigint
    'status_column'      => 'STATUS_COLUMN_NAME', # defaults to freesidestatus
    'status_column_info' => 'varchar(32)', # defaults to varchar(32)
    'column_map'         => { #freeside => remote_db
      'freeside_column'    => 'remote_db_column',
      'freeside_column'    => sub { my $row = shift; $row->{remote_db_column}; },
    },
    'batch_name'         => 'batch_name', # cdr_batch name -import-date gets appended.
  );

=head1 DESCRIPTION

CDR importing

=head1 CLASS METHODS

=item dbi_import

=cut

sub dbi_import {
  my $class = shift;
  my %args = @_; #args are specifed by the script using this sub

  my %opt; #opt is specified for each install / run of the script
  getopts('H:U:P:D:T:c:L:S:', \%opt);

  my $user = shift(@ARGV) or die $class->cli_usage;
  my $database = $opt{D} || $args{database};
  my $table = $opt{T} || $args{table};
  my $pkey = $args{primary_key};
  my $pkey_info = $args{primary_key_info} ? $args{primary_key_info} : 'BIGINT';
  my $status_table = $opt{S} || $args{status_table};
  my $dbd_type = $args{'dbd'} ? $args{'dbd'} : 'Pg';
  my $status_column = $args{status_column} ? $args{status_column} : 'freesidestatus';
  my $status_column_info = $args{status_column_info} ? $args{status_column} : 'VARCHAR(32)';

  my $queries = get_queries({
    'dbd'                 => $dbd_type,
    'host'                => $opt{H},
    'table'               => $table,
    'status_column'       => $status_column,
    'status_column_info'  => $status_column_info,
    'status_table'        => $status_table,
    'primary_key'         => $pkey,
    'primary_key_info'    => $pkey_info,
  });

  my $dsn = 'dbi:'. $dbd_type . $queries->{connect_type};
  $dsn .= ";database=$database" if $database;

  my $dbi = DBI->connect($dsn, $opt{U}, $opt{P}) 
    or die $DBI::errstr;

  adminsuidsetup $user;

  ## check for status table if using. if not there create it.
  if ($status_table) {
    my $status = $dbi->selectall_arrayref( $queries->{check_statustable} );
    if( ! @$status ) {
      print "Adding status table $status_table ...\n";
      $dbi->do( $queries->{create_statustable} )
        or die $dbi->errstr;
    }
  }
  ## check for column freeside status if not using status table and create it if not there.
  else {
    my $status = $dbi->selectall_arrayref( $queries->{check_statuscolumn} );
    if( ! @$status ) {
      print "Adding $status_column column...\n";
      $dbi->do( $queries->{create_statuscolumn} )
        or die $dbi->errstr;
    }
  }

  #my @cols = values %{ $args{column_map} };
  my $sql = "SELECT $table.* FROM $table "; # join(',', @cols). " FROM $table ".
  $sql .=  "LEFT JOIN $status_table ON ( $table.$pkey = $status_table.$pkey ) "
    if $status_table;
  $sql .= "WHERE  $status_column IS NULL ";

  #$sql .= ' LIMIT '. $opt{L} if $opt{L};
  my $sth = $dbi->prepare($sql);
  $sth->execute or die $sth->errstr. " executing $sql";

  my $cdr_batch = new FS::cdr_batch({ 
      'cdrbatch' => $args{batch_name} . '-import-'. time2str('%Y/%m/%d-%T',time),
    });
  my $error = $cdr_batch->insert;
  die $error if $error;
  my $cdrbatchnum = $cdr_batch->cdrbatchnum;
  my $imported = 0;

  my $row;
  while ( $row = $sth->fetchrow_hashref ) {

    my %hash = ( 'cdrbatchnum' => $cdrbatchnum );
    foreach my $field ( keys %{ $args{column_map} } ) {
      my $col_or_coderef = $args{column_map}->{$field};
      if ( ref($col_or_coderef) eq 'CODE' ) {
        $hash{$field} = &{ $col_or_coderef }( $row );
      } else {
        $hash{$field} = $row->{ $col_or_coderef };
      }
      $hash{$field} = '' if $hash{$field} =~ /^\s+$/; #IVR (MSSQL?) bs
    }

    my $cdr = FS::cdr->new(\%hash);

    $cdr->cdrtypenum($opt{c}) if $opt{c};

    my $pkey_value = $row->{$pkey};

    #print "$pkey_value\n" if $opt{v};
    my $error = $cdr->insert;

    if ($error) {

      #die "$pkey_value: failed import: $error\n";
      print "$pkey_value: failed import: $error\n";

    } else {

      $imported++;

      my $st_sql;
      if ( $args{status_table} ) {

        $st_sql = 
          'INSERT INTO '. $status_table. " ( $pkey, $status_column ) ".
            " VALUES ( ?, 'done' )";

      } else {

        $st_sql = "UPDATE $table SET $status_column = 'done' WHERE $pkey = ?";

      }

      my $updated = $dbi->do($st_sql, undef, $pkey_value );
      #$updates += $updated;
      die "failed to set status: ".$dbi->errstr."\n" unless $updated;

    }

    if ( $opt{L} && $imported >= $opt{L} ) {
      $sth->finish;
      last;
    }

  }
  print "Done.\n";
  print "Imported $imported CDRs.\n" if $imported;

  $dbi->disconnect;

}

sub cli_usage {
  "Usage: \n  $0\n\t-H hostname\n\t[ -D database ]\n\t-U user\n\t-P password\n\t[ -c cdrtypenum ]\n\t[ -L num_cdrs_limit ]\n\t[ -T table ]\n\t[ -S status table ]\n\tfreesideuser\n";
}

sub get_queries {
  #my ($dbd, $host, $table, $column, $column_create_info, $status_table, $primary_key, $primary_key_info) = @_;
  my $info = shift;

  #get host and port information.
  my ($host, $port) = split /:/, $info->{host};
  $host ||= 'localhost';
  $port ||= '5000'; # check for pg default 5000 is sybase.

  my %dbi_connect_types = (
    'Sybase'  => ':host='.$host.';port='.$port,
    'Pg'      => ':host='.$info->{host},
  );

  #Check for freeside status table
  my %dbi_check_statustable = (
    'Sybase'  => "SELECT * FROM sysobjects WHERE name = '$info->{status_table}'",
    'Pg'      => "SELECT * FROM information_schema.columns WHERE table_schema = 'public' AND table_name = '$info->{status_table}' AND column_name = '$info->{status_column}'",
  );

  #Create freeside status table
  my %dbi_create_statustable = (
    'Sybase'  => "CREATE TABLE $info->{status_table} ( $info->{primary_key} $info->{primary_key_info}, $info->{status_column} $info->{status_column_info} )",
    'Pg'      => "CREATE TABLE $info->{status_table} ( $info->{primary_key} $info->{primary_key_info}, $info->{status_column} $info->{status_column_info} )",
  );

  #Check for freeside status column
  my %dbi_check_statuscolumn = (
    'Sybase'  => "SELECT syscolumns.name FROM sysobjects
                  JOIN syscolumns ON sysobjects.id = syscolumns.id
                  WHERE sysobjects.name LIKE '$info->{table}' AND syscolumns.name = '$info->{status_column}'",
    'Pg'      => "SELECT * FROM information_schema.columns WHERE table_schema = 'public' AND table_name = '$info->{table}' AND column_name = '$info->{status_column}' ",
  );

    #Create freeside status column
  my %dbi_create_statuscolumn = (
    'Sybase'  => "ALTER TABLE $info->{table} ADD $info->{status_column} $info->{status_column_info} NULL",
    'Pg'      => "ALTER TABLE $info->{table} ADD COLUMN $info->{status_column} $info->{status_column_info}",
  );

  my $queries = {
    'connect_type'         =>  $dbi_connect_types{$info->{dbd}},
    'check_statustable'    =>  $dbi_check_statustable{$info->{dbd}},
    'create_statustable'   =>  $dbi_create_statustable{$info->{dbd}},
    'check_statuscolumn'   =>  $dbi_check_statuscolumn{$info->{dbd}},
    'create_statuscolumn'  =>  $dbi_create_statuscolumn{$info->{dbd}},
  };

  return $queries;
}

=head1 BUGS

currently works with Pg(Postgresql) and Sybase(Sybase AES)

Sparse documentation.

=head1 SEE ALSO

L<FS::cdr>

=cut

1;
