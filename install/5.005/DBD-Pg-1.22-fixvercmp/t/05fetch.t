use strict;
use DBI;
use Test::More;

if (defined $ENV{DBI_DSN}) {
  plan tests => 10;
} else {
  plan skip_all => 'cannot test without DB info';
}

my $dbh = DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS},
		       {RaiseError => 1, AutoCommit => 0}
		      );
ok(defined $dbh,
   'connect with transaction'
  );

$dbh->do(q{INSERT INTO test (id, name, val) VALUES (1, 'foo', 'horse')});
$dbh->do(q{INSERT INTO test (id, name, val) VALUES (2, 'bar', 'chicken')});
$dbh->do(q{INSERT INTO test (id, name, val) VALUES (3, 'baz', 'pig')});
ok($dbh->commit(),
   'commit'
   );

my $sql = <<SQL;
  SELECT id
  , name
  FROM test
SQL
my $sth = $dbh->prepare($sql);
$sth->execute();

my $rows = 0;
while (my ($id, $name) = $sth->fetchrow_array()) {
  if (defined($id) && defined($name)) {
    $rows++;
  }
}
$sth->finish();
ok($rows == 3,
   'fetch three rows'
  );

$sql = <<SQL;
       SELECT id
       , name
       FROM test
       WHERE 1 = 0
SQL
$sth = $dbh->prepare($sql);
$sth->execute();

$rows = 0;
while (my ($id, $name) = $sth->fetchrow_array()) {
  $rows++;
}
$sth->finish();

ok($rows == 0,
   'fetch zero rows'
   );

$sql = <<SQL;
       SELECT id
       , name
       FROM test
       WHERE id = ?
SQL
$sth = $dbh->prepare($sql);
$sth->execute(1);

$rows = 0;
while (my ($id, $name) = $sth->fetchrow_array()) {
  if (defined($id) && defined($name)) {
    $rows++;
  }
}
$sth->finish();

ok($rows == 1,
   'fetch one row on id'
  );

# Attempt to test whether or not we can get unicode out of the database
# correctly.  Reuse the previous sth.
SKIP: {
  eval "use Encode";
  skip "need Encode module for unicode tests", 3 if $@;
  local $dbh->{pg_enable_utf8} = 1;
  $dbh->do("INSERT INTO test (id, name, val) VALUES (4, '\001\000dam', 'cow')");
  $sth->execute(4);
  my ($id, $name) = $sth->fetchrow_array();
  ok(Encode::is_utf8($name),
     'returned data has utf8 bit set'
    );
  is(length($name), 4,
     'returned utf8 data is not corrupted'
    );
  $sth->finish();
  $sth->execute(1);
  my ($id2, $name2) = $sth->fetchrow_array();
  ok(! Encode::is_utf8($name2),
     'returned ASCII data has not got utf8 bit set'
    );
  $sth->finish();
}

$sql = <<SQL;
       SELECT id
       , name
       FROM test
       WHERE name = ?
SQL
$sth = $dbh->prepare($sql);
$sth->execute('foo');

$rows = 0;
while (my ($id, $name) = $sth->fetchrow_array()) {
  if (defined($id) && defined($name)) {
    $rows++;
  }
}
$sth->finish();

ok($rows == 1,
   'fetch one row on name'
   );

ok($dbh->disconnect(),
   'disconnect'
  );
