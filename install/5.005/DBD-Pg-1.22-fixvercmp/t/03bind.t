use strict;
use DBI;
use Test::More;

if (defined $ENV{DBI_DSN}) {
  plan tests => 11;
} else {
  plan skip_all => 'cannot test without DB info';
}

my $dbh = DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS},
		       {RaiseError => 1, AutoCommit => 0}
		      );
ok(defined $dbh,
   'connect with transaction'
  );

my $sql = <<SQL;
  SELECT id
  , name
  FROM test
  WHERE id = ?
SQL
my $sth = $dbh->prepare($sql);
ok(defined $sth,
   "prepare: $sql"
  );

ok($sth->bind_param(1, 'foo'),
   'bind int column with string'
   );

ok($sth->bind_param(1, 1),
   'rebind int column with int'
   );

$sql = <<SQL;
   SELECT id
   , name
   FROM test
   WHERE id = ?
   AND name = ?
SQL
$sth = $dbh->prepare($sql);
ok(defined $sth,
   "prepare: $sql"
  );

ok($sth->bind_param(1, 'foo'),
   'bind int column with string',
  );
ok($sth->bind_param(2, 'bar'),
   'bind string column with text'
   );
ok($sth->bind_param(2, 'baz'),
   'rebind string column with text'
  );

ok($sth->finish(),
   'finish'
   );

# Make sure that we get warnings when we try to use SQL_BINARY.
{
  local $SIG{__WARN__} =
    sub { ok($_[0] =~ /^Use of SQL type SQL_BINARY/,
	     'warning with SQL_BINARY'
	    );
	};

  $sql = <<SQL;
	 SELECT id
	 , name
	 FROM test
	 WHERE id = ?
	 AND name = ?
SQL
  $sth = $dbh->prepare($sql);

  $sth->bind_param(1, 'foo', DBI::SQL_BINARY);
}

ok($dbh->disconnect(),
   'disconnect'
  );
