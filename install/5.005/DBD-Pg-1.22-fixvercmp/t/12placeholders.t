use strict;
use DBI;
use Test::More;

if (defined $ENV{DBI_DSN}) {
  plan tests => 9;
} else {
  plan skip_all => 'cannot test without DB info';
}

my $dbh = DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS},
		       {RaiseError => 1, AutoCommit => 0}
		      );
ok(defined $dbh,
   'connect with transaction'
  );

my $quo = $dbh->quote("\\'?:");
my $sth = $dbh->prepare(qq{
			INSERT INTO test (name) VALUES ($quo)
		       });
$sth->execute();

my $sql = <<SQL;
	SELECT name
	FROM test
	WHERE name = $quo;
SQL
$sth = $dbh->prepare($sql);
$sth->execute();

my ($retr) = $sth->fetchrow_array();
ok((defined($retr) && $retr eq "\\'?:"),
   'fetch'
  );

eval {
  local $dbh->{PrintError} = 0;
  $sth->execute('foo');
};
ok($@,
   'execute with one bind param where none expected'
  );

$sql = <<SQL;
       SELECT name
       FROM test
       WHERE name = ?
SQL
$sth = $dbh->prepare($sql);

$sth->execute("\\'?:");

($retr) = $sth->fetchrow_array();
ok((defined($retr) && $retr eq "\\'?:"),
   'execute with ? placeholder'
  );

$sql = <<SQL;
       SELECT name
       FROM test
       WHERE name = :1
SQL
$sth = $dbh->prepare($sql);

$sth->execute("\\'?:");

($retr) = $sth->fetchrow_array();
ok((defined($retr) && $retr eq "\\'?:"),
   'execute with :1 placeholder'
  );

$sql = <<SQL;
       SELECT name
       FROM test
       WHERE name = '?'
SQL
$sth = $dbh->prepare($sql);

eval {
  local $dbh->{PrintError} = 0;
  $sth->execute('foo');
};
ok($@,
   'execute with quoted ?'
  );

$sql = <<SQL;
       SELECT name
       FROM test
       WHERE name = ':1'
SQL
$sth = $dbh->prepare($sql);

eval {
  local $dbh->{PrintError} = 0;
  $sth->execute('foo');
};
ok($@,
   'execute with quoted :1'
  );

$sql = <<SQL;
       SELECT name
       FROM test
       WHERE name = '\\\\'
       AND name = '?'
SQL
$sth = $dbh->prepare($sql);

eval {
  local $dbh->{PrintError} = 0;
  local $sth->{PrintError} = 0;
  $sth->execute('foo');
};
ok($@,
   'execute with quoted ?'
  );

$sth->finish();
$dbh->rollback();

ok($dbh->disconnect(),
   'disconnect'
  );
