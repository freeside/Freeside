use strict;
use DBI;
use Test::More;

if (defined $ENV{DBI_DSN}) {
  plan tests => 8;
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
        SELECT *
          FROM test
SQL

ok($dbh->prepare($sql),
   "prepare: $sql"
  );

$sql = <<SQL;
        SELECT id
          FROM test
SQL

ok($dbh->prepare($sql),
   "prepare: $sql"
  );

$sql = <<SQL;
        SELECT id
             , name
          FROM test
SQL

ok($dbh->prepare($sql),
   "prepare: $sql"
  );

$sql = <<SQL;
        SELECT id
             , name
          FROM test
         WHERE id = 1
SQL

ok($dbh->prepare($sql),
   "prepare: $sql"
  );

$sql = <<SQL;
        SELECT id
             , name
          FROM test
         WHERE id = ?
SQL

ok($dbh->prepare($sql),
   "prepare: $sql"
  );

$sql = <<SQL;
        SELECT *
           FROM test
         WHERE id = ?
           AND name = ?
           AND value = ?
           AND score = ?
           and data = ?
SQL

ok($dbh->prepare($sql),
   "prepare: $sql"
  );

ok($dbh->disconnect(),
   'disconnect'
  );
