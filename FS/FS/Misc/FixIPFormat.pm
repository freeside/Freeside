package FS::Misc::FixIPFormat;
use strict;
use warnings;
use FS::Record qw(dbh qsearchs);
use FS::upgrade_journal;

=head1 NAME

FS::Misc::FixIPFormat - Functions to repair bad IP address input

=head1 DESCRIPTION

Provides functions for freeside_upgrade to check IP address storage for
user-entered leading 0's in IP addresses.  When read from database, NetAddr::IP
would treat the number as octal isntead of decimal.  If a user entered
10.0.0.052, this may get invisibly translated to 10.0.0.42 when exported.
Base8:52 = Base0:42

Tied to freeside_upgrade with journal name TABLE__fixipformat

see: RT# 80555

=head1 SYNOPSIS

Usage:

    # require, not use - this module is only run once
    require FS::Misc::FixIPFormat;

    my $error = FS::Misc::FixIPFormat::fix_bad_addresses_in_table(
      'svc_broadband', 'svcnum', 'ip_addr'
    );
    die "oh no!" if $error;

=head2 fix_bad_addresses_in_table TABLE, ID_COLUMN, IP_COLUMN

$error = fix_bad_addresses_in_table( 'svc_broadband', 'svcnum', 'ip_addr' );

=cut

sub fix_bad_addresses_in_table {
  my ( $table ) = @_;
  return if FS::upgrade_journal->is_done("${table}__fixipformat");
  for my $id ( find_bad_addresses_in_table( @_ )) {
    if ( my $error = fix_ip_for_record( $id, @_ )) {
      die "fix_bad_addresses_in_table(): $error";
    }
  }
  FS::upgrade_journal->set_done("${table}__fixipformat");
  0;
}

=head2 find_bad_addresses_in_table TABLE, ID_COLUMN, IP_COLUMN

@id = find_bad_addresses_in_table( 'svc_broadband', 'svcnum', 'ip_addr' );

=cut

sub find_bad_addresses_in_table {
  my ( $table, $id_col, $ip_col ) = @_;
  my @fix_ids;

  # using DBI directly for performance
  my $sql_statement = "
    SELECT $id_col, $ip_col
    FROM $table
    WHERE $ip_col IS NOT NULL
  ";
  my $sth = dbh->prepare( $sql_statement ) || die "SQL ERROR ".dbh->errstr;
  $sth->execute || die "SQL ERROR ".dbh->errstr;
  while ( my $row = $sth->fetchrow_hashref ) {
    push @fix_ids, $row->{ $id_col }
      if $row->{ $ip_col } =~ /[\.^]0\d/;
  }
  @fix_ids;
}

=head2 fix_ip_for_record ID, TABLE, ID_COLUMN, IP_COLUMN

Attempt to strip the leading 0 from a stored IP address record.  If
the corrected IP address would be a duplicate of another record in the
same table, thow an exception.

$error = fix_ip_for_record( 1001, 'svc_broadband', 'svcnum', 'ip_addr', );

=cut

sub fix_ip_for_record {
  my ( $id, $table, $id_col, $ip_col ) = @_;

  my $row = qsearchs($table, {$id_col => $id})
    || die "Error finding $table record for id $id";

  my $ip = $row->getfield( $ip_col );
  my $fixed_ip = join( '.',
    map{ int($_) }
    split( /\./, $ip )
  );

  return undef unless $ip ne $fixed_ip;

  if ( my $dupe_row = qsearchs( $table, {$ip_col => $fixed_ip} )) {
    if ( $dupe_row->getfield( $id_col ) != $row->getfield( $id_col )) {
      # Another record in the table has this IP address
      # Eg one ip is provisioned as 10.0.0.51 and another is
      # provisioned as 10.0.0.051.  Cannot auto-correct by simply
      # trimming leading 0.  Die, let support decide how to fix.

      die "Invalid IP address could not be auto-corrected - ".
          "($table - $id_col = $id, $ip_col = $ip) ".
           "colission with another reocrd - ".
           "($table - $id_col = ".$dupe_row->getfield( $id_col )." ".
           "$ip_col = ",$dupe_row->getfield( $ip_col )." ) - ".
         "The entry must be corrected to continue";
    }
  }

  warn "Autocorrecting IP address problem for ".
       "($table - $id_col = $id, $ip_col = $ip) $fixed_ip\n";
  $row->setfield( $ip_col, $fixed_ip );
  $row->replace;
}

1;
