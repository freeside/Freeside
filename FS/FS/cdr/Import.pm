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
    'dbd'         => 'mysql', #Pg, Sybase, etc.
    'table'       => 'TABLE_NAME',
    'primary_key' => 'BILLING_ID',
    'column_map'  => { #freeside => remote_db
      'freeside_column' => 'remote_db_column',
      'freeside_column' => sub { my $row = shift; $row->{remote_db_column}; },
    },
  );

=head1 DESCRIPTION

CDR importing

=head1 CLASS METHODS

=item do_cli_import

=cut

sub dbi_import {
  my $class = shift;
  my %args = @_; #args are specifed by the script using this sub

  my %opt; #opt is specified for each install / run of the script
  getopts('H:U:P:D:T:c:L:', \%opt);
  my $user = shift(@ARGV) or die $class->cli_usage;

  $opt{D} ||= $args{database};

  my $dsn = 'dbi:'. $args{dbd};
  #$dsn .= ":host=$opt{H}"; #if $opt{H};
  $dsn .= ":server=$opt{H}"; #if $opt{H};
  $dsn .= ";database=$opt{D}" if $opt{D};

  my $dbi = DBI->connect($dsn, $opt{U}, $opt{P}) 
    or die $DBI::errstr;

  adminsuidsetup $user;

  #my $fsdbh = FS::UID::dbh;

  my $table = $opt{T} || $args{table};
  my $pkey = $args{primary_key};

  #just doing this manually with IVR MSSQL databases for now
  #  # check for existence of freesidestatus
  #  my $status = $dbi->selectall_arrayref("SHOW COLUMNS FROM $table WHERE Field = 'freesidestatus'");
  #  if( ! @$status ) {
  #    print "Adding freesidestatus column...\n";
  #    $dbi->do("ALTER TABLE $table ADD COLUMN freesidestatus varchar(32)")
  #      or die $dbi->errstr;
  #  }
  #  else {
  #    print "freesidestatus column present\n";
  #  }

  #my @cols = values %{ $args{column_map} };
  my $sql = "SELECT * FROM $table ". # join(',', @cols). " FROM $table ".

            ' WHERE freesidestatus IS NULL ';
  #$sql .= ' LIMIT '. $opt{L} if $opt{L};
  my $sth = $dbi->prepare($sql);
  $sth->execute or die $sth->errstr. " executing $sql";
  #MySQL-specific print "Importing ".$sth->rows." records...\n";

  my $cdr_batch = new FS::cdr_batch({ 
      'cdrbatch' => 'IVR-import-'. time2str('%Y/%m/%d-%T',time),
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

    #print $row->{$pkey},"\n" if $opt{v};
    my $error = $cdr->insert;
    if ($error) {
      #die $row->{$pkey} . ": failed import: $error\n";
      print $row->{$pkey} . ": failed import: $error\n";
    } else {
      $imported++;

      my $updated = $dbi->do(
        "UPDATE $table SET freesidestatus = 'done' WHERE $pkey = ?",
        undef,
        $row->{'$pkey'}
      );
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
  #"Usage: \n  $0\n\t[ -H hostname ]\n\t-D database\n\t-U user\n\t-P password\n\tfreesideuser\n";
  #"Usage: \n  $0\n\t-H hostname\n\t-D database\n\t-U user\n\t-P password\n\t[ -c cdrtypenum ]\n\tfreesideuser\n";
  "Usage: \n  $0\n\t-H hostname\n\t[ -D database ]\n\t-U user\n\t-P password\n\t[ -c cdrtypenum ]\n\t[ -L num_cdrs_limit ]\n\tfreesideuser\n";
}

=head1 BUGS

Not everything has been refactored out of the various bin/cdr-*.import scripts,
let alone other places.

Sparse documentation.

=head1 SEE ALSO

L<FS::cdr>

=cut

1;
