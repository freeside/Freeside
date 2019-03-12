package FS::DBI;
use strict;
use warnings;
use base qw( DBI );

=head1 NAME

FS::DBI - Freeside wrapper for DBI

=head1 SYNOPSIS

  use FS::DBI;
  
  $dbh = FS::DBI->connect( @args );
  $dbh->do(
    'UPDATE table SET foo = ? WHERE bar = ?',
    undef,
    $foo, $bar
  ) or die $dbh->errstr;

See L<DBI>

=head1 DESCRIPTION

Allow Freeside to manage how DBI is used when necessary

=head2 Legacy databases and DBD::Pg v3.0+

Breaking behavior was introduced in DBD::Pg version 3.0.0
in regards to L<DBD::Pg/pg_enable_utf8>.

Some freedside databases are legacy databases with older encodings
and locales. pg_enable_utf8 no longer sets client_encoding to utf8
on non-utf8 databases, causing crashes and data corruption.

FS::DBI->connect() enforces utf8 client_encoding on all DBD::Pg connections

=head1 METHODS

=head2 connect @connect_args

For usage, see L<DBI/connect>

Force utf8 client_encoding on DBD::Pg connections

=cut

sub connect {
  my $class = shift;
  my $dbh = $class->SUPER::connect( @_ );

  if ( $_[0] =~ /^DBI:Pg/ ) {
    $dbh->do('SET client_encoding TO UTF8;')
      or die sprintf 'Error setting client_encoding to UTF8: %s', $dbh->errstr;

    # DBD::Pg requires touching this attribute when changing the client_encoding
    # on an already established connection, to get expected behavior.
    $dbh->{pg_enable_utf8} = -1;
  }

  $dbh;
}

# Stub required to subclass DBI
package FS::DBI::st;
use base qw( DBI::st );

# Stub required to subclass DBI
package FS::DBI::db;
use base qw( DBI::db );

1;
