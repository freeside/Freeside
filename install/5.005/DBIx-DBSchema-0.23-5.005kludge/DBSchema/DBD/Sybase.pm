package DBIx::DBSchema::DBD::Sybase;

use strict;
use vars qw($VERSION @ISA %typemap);
use DBIx::DBSchema::DBD;

$VERSION = '0.03';
@ISA = qw(DBIx::DBSchema::DBD);

%typemap = (
#  'empty' => 'empty'
);

=head1 NAME

DBIx::DBSchema::DBD::Sybase - Sybase database driver for DBIx::DBSchema

=head1 SYNOPSIS

use DBI;
use DBIx::DBSchema;

$dbh = DBI->connect('dbi:Sybase:dbname=database', 'user', 'pass');
$schema = new_native DBIx::DBSchema $dbh;

=head1 DESCRIPTION

This module implements a Sybase driver for DBIx::DBSchema. 

=cut

sub columns {
  my($proto, $dbh, $table) = @_;

  my $sth = $dbh->prepare("sp_columns \@table_name=$table") 
  or die $dbh->errstr;

  $sth->execute or die $sth->errstr;
  my @cols = map {
    [
      $_->{'column_name'},
      $_->{'type_name'},
      ($_->{'nullable'} ? 1 : ''),
      $_->{'length'},
      '', #default
      ''  #local
    ]
  } @{ $sth->fetchall_arrayref({}) };
  $sth->finish;

  @cols;
}

sub primary_key {
    return("StubbedPrimaryKey");
}


sub unique {
  my($proto, $dbh, $table) = @_;
  my $gratuitous = { map { $_ => [ $proto->_index_fields($dbh, $table, $_ ) ] }
      grep { $proto->_is_unique($dbh, $_ ) }
        $proto->_all_indices($dbh, $table)
  };
}

sub index {
  my($proto, $dbh, $table) = @_;
  my $gratuitous = { map { $_ => [ $proto->_index_fields($dbh, $table, $_ ) ] }
      grep { ! $proto->_is_unique($dbh, $_ ) }
        $proto->_all_indices($dbh, $table)
  };
}

sub _all_indices {
  my($proto, $dbh, $table) = @_;

  my $sth = $dbh->prepare_cached(<<END) or die $dbh->errstr;
    SELECT name
    FROM sysindexes
    WHERE id = object_id('$table') and indid between 1 and 254
END
  $sth->execute or die $sth->errstr;
  my @indices = map { $_->[0] } @{ $sth->fetchall_arrayref() };
  $sth->finish;
  $sth = undef;
  @indices;
}

sub _index_fields {
  my($proto, $dbh, $table, $index) = @_;

  my @keys;

  my ($indid) = $dbh->selectrow_array("select indid from sysindexes where id = object_id('$table') and name = '$index'");
  for (1..30) {
    push @keys, $dbh->selectrow_array("select index_col('$table', $indid, $_)") || ();
  }

  return @keys;
}

sub _is_unique {
  my($proto, $dbh, $table, $index) = @_;

  my ($isunique) = $dbh->selectrow_array("select status & 2 from sysindexes where id = object_id('$table') and name = '$index'");

  return $isunique;
}

=head1 AUTHOR

Charles Shapiro <charles.shapiro@numethods.com>
(courtesy of Ivan Kohler <ivan-dbix-dbschema@420.am>)

Mitchell Friedman <mitchell.friedman@numethods.com>

Bernd Dulfer <bernd@widd.de>

=head1 COPYRIGHT

Copyright (c) 2001 Charles Shapiro, Mitchell J. Friedman
Copyright (c) 2001 nuMethods LLC.
All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 BUGS

Yes.

The B<primary_key> method does not yet work.

=head1 SEE ALSO

L<DBIx::DBSchema>, L<DBIx::DBSchema::DBD>, L<DBI>, L<DBI::DBD>

=cut 

1;

