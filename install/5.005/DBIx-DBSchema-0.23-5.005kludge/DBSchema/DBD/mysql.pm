package DBIx::DBSchema::DBD::mysql;

use strict;
use vars qw($VERSION @ISA %typemap);
use DBIx::DBSchema::DBD;

$VERSION = '0.03';
@ISA = qw(DBIx::DBSchema::DBD);

%typemap = (
  'TIMESTAMP'      => 'DATETIME',
  'SERIAL'         => 'INTEGER',
  'BOOL'           => 'TINYINT',
  'LONG VARBINARY' => 'LONGBLOB',
);

=head1 NAME

DBIx::DBSchema::DBD::mysql - MySQL native driver for DBIx::DBSchema

=head1 SYNOPSIS

use DBI;
use DBIx::DBSchema;

$dbh = DBI->connect('dbi:mysql:database', 'user', 'pass');
$schema = new_native DBIx::DBSchema $dbh;

=head1 DESCRIPTION

This module implements a MySQL-native driver for DBIx::DBSchema.

=cut

sub columns {
  my($proto, $dbh, $table ) = @_;
  my $sth = $dbh->prepare("SHOW COLUMNS FROM $table") or die $dbh->errstr;
  $sth->execute or die $sth->errstr;
  map {
    $_->{'Type'} =~ /^(\w+)\(?([\d\,]+)?\)?( unsigned)?$/
      or die "Illegal type: ". $_->{'Type'}. "\n";
    my($type, $length) = ($1, $2);
    [
      $_->{'Field'},
      $type,
      $_->{'Null'},
      $length,
      $_->{'Default'},
      $_->{'Extra'}
    ]
  } @{ $sth->fetchall_arrayref( {} ) };
}

#sub primary_key {
#  my($proto, $dbh, $table ) = @_;
#  my $primary_key = '';
#  my $sth = $dbh->prepare("SHOW INDEX FROM $table")
#    or die $dbh->errstr;
#  $sth->execute or die $sth->errstr;
#  my @pkey = map { $_->{'Column_name'} } grep {
#    $_->{'Key_name'} eq "PRIMARY"
#  } @{ $sth->fetchall_arrayref( {} ) };
#  scalar(@pkey) ? $pkey[0] : '';
#}

sub primary_key {
  my($proto, $dbh, $table) = @_;
  my($pkey, $unique_href, $index_href) = $proto->_show_index($dbh, $table);
  $pkey;
}

sub unique {
  my($proto, $dbh, $table) = @_;
  my($pkey, $unique_href, $index_href) = $proto->_show_index($dbh, $table);
  $unique_href;
}

sub index {
  my($proto, $dbh, $table) = @_;
  my($pkey, $unique_href, $index_href) = $proto->_show_index($dbh, $table);
  $index_href;
}

sub _show_index {
  my($proto, $dbh, $table ) = @_;
  my $sth = $dbh->prepare("SHOW INDEX FROM $table")
    or die $dbh->errstr;
  $sth->execute or die $sth->errstr;

  my $pkey = '';
  my(%index, %unique);
  foreach my $row ( @{ $sth->fetchall_arrayref({}) } ) {
    if ( $row->{'Key_name'} eq 'PRIMARY' ) {
      $pkey = $row->{'Column_name'};
    } elsif ( $row->{'Non_unique'} ) { #index
      push @{ $index{ $row->{'Key_name'} } }, $row->{'Column_name'};
    } else { #unique
      push @{ $unique{ $row->{'Key_name'} } }, $row->{'Column_name'};
    }
  }

  ( $pkey, \%unique, \%index );
}

=head1 AUTHOR

Ivan Kohler <ivan-dbix-dbschema@420.am>

=head1 COPYRIGHT

Copyright (c) 2000 Ivan Kohler
Copyright (c) 2000 Mail Abuse Prevention System LLC
All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 BUGS

=head1 SEE ALSO

L<DBIx::DBSchema>, L<DBIx::DBSchema::DBD>, L<DBI>, L<DBI::DBD>

=cut 

1;

