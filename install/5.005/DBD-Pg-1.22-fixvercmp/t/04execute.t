use strict;
use DBI;
use Test::More;

if (defined $ENV{DBI_DSN}) {
  plan tests => 13;
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

$sth->bind_param(1, 1);
ok($sth->execute(),
   'exectute with one bind param'
  );

$sth->bind_param(1, 2);
ok($sth->execute(),
   'exectute with rebinding one param'
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

$sth->bind_param(1, 2);
$sth->bind_param(2, 'foo');
ok($sth->execute(),
   'exectute with two bind params'
  );

eval {
  local $dbh->{PrintError} = 0;
  $sth = $dbh->prepare($sql);
  $sth->bind_param(1, 2);
  $sth->execute();
};
ok(!$@,
  'execute with only first of two params bound'
  );

eval {
  local $dbh->{PrintError} = 0;
  $sth = $dbh->prepare($sql);
  $sth->bind_param(2, 'foo');
  $sth->execute();
};
ok(!$@,
  'execute with only second of two params bound'
  );

eval {
  local $dbh->{PrintError} = 0;
  $sth = $dbh->prepare($sql);
  $sth->execute();
};
ok(!$@,
  'execute with neither of two params bound'
  );

$sth = $dbh->prepare($sql);
ok($sth->execute(1, 'foo'),
   'execute with both params bound in execute'
   );

eval {
  local $dbh->{PrintError} = 0;
  $sth = $dbh->prepare(q{
			 SELECT id
			 , name
			 FROM test
			 WHERE id = ?
			 AND name = ?
			});
  $sth->execute(1);
};
ok($@,
  'execute with only one of two params bound in execute'
  );


ok($sth->finish(),
   'finish'
   );

ok($dbh->disconnect(),
   'disconnect'
  );
