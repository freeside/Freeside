use strict;
use DBI;
use Test::More;

if (defined $ENV{DBI_DSN}) {
  plan tests => 3;
} else {
  plan skip_all => 'cannot test without DB info';
}

my $dbh = DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS},
		       {RaiseError => 1, PrintError => 0, AutoCommit => 0}
		      );
ok(defined $dbh,
   'connect with transaction'
  );

my $sth = $dbh->prepare(q{SELECT * FROM test});
ok($dbh->disconnect(),
   'disconnect with un-finished statement'
  );

eval {
  $sth->execute();
};
ok($@,
   'execute on disconnected statement'
  );
