use strict;
use DBI;
use Test::More;

if (defined $ENV{DBI_DSN}) {
  plan tests => 18;
} else {
  plan skip_all => 'cannot test without DB info';
}

my $dbh1 = DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS},
			{RaiseError => 1, AutoCommit => 0}
		       );
ok(defined $dbh1,
   'connect first dbh'
  );

my $dbh2 = DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS},
			{RaiseError => 1, AutoCommit => 0}
		       );
ok(defined $dbh2,
   'connect second dbh'
  );

$dbh1->do(q{DELETE FROM test});
ok($dbh1->commit(),
   'delete'
   );

my $rows = ($dbh1->selectrow_array(q{SELECT COUNT(*) FROM test}))[0];
ok($rows == 0,
   'fetch on empty table from dbh1'
  );

$rows = ($dbh2->selectrow_array(q{SELECT COUNT(*) FROM test}))[0];
ok($rows == 0,
   'fetch on empty table from dbh2'
  );

$dbh1->do(q{INSERT INTO test (id, name, val) VALUES (1, 'foo', 'horse')});
$dbh1->do(q{INSERT INTO test (id, name, val) VALUES (2, 'bar', 'chicken')});
$dbh1->do(q{INSERT INTO test (id, name, val) VALUES (3, 'baz', 'pig')});

$rows = ($dbh1->selectrow_array(q{SELECT COUNT(*) FROM test}))[0];
ok($rows == 3,
   'fetch three rows on dbh1'
  );

$rows = ($dbh2->selectrow_array(q{SELECT COUNT(*) FROM test}))[0];
ok($rows == 0,
   'fetch on dbh2 before commit'
  );

ok($dbh1->commit(),
   'commit work'
  );

$rows = ($dbh1->selectrow_array(q{SELECT COUNT(*) FROM test}))[0];
ok($rows == 3,
   'fetch on dbh1 after commit'
  );

$rows = ($dbh2->selectrow_array(q{SELECT COUNT(*) FROM test}))[0];
ok($rows == 3,
   'fetch on dbh2 after commit'
  );

ok($dbh1->do(q{DELETE FROM test}),
   'delete'
  );

$rows = ($dbh1->selectrow_array(q{SELECT COUNT(*) FROM test}))[0];
ok($rows == 0,
   'fetch on empty table from dbh1'
  );

$rows = ($dbh2->selectrow_array(q{SELECT COUNT(*) FROM test}))[0];
ok($rows == 3,
   'fetch on from dbh2 without commit'
  );

ok($dbh1->rollback(),
   'rollback'
  );

$rows = ($dbh1->selectrow_array(q{SELECT COUNT(*) FROM test}))[0];
ok($rows == 3,
   'fetch on from dbh1 after rollback'
  );

$rows = ($dbh2->selectrow_array(q{SELECT COUNT(*) FROM test}))[0];
ok($rows == 3,
   'fetch on from dbh2 after rollback'
  );

ok($dbh1->disconnect(),
   'disconnect on dbh1'
);

ok($dbh2->disconnect(),
   'disconnect on dbh2'
);
