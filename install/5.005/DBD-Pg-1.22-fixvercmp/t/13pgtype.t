use strict;
use DBI;
use Test::More;

if (defined $ENV{DBI_DSN}) {
  plan tests => 3;
} else {
  plan skip_all => 'cannot test without DB info';
}

my $dbh = DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS},
		       {RaiseError => 1, AutoCommit => 0}
		      );
ok(defined $dbh,
   'connect with transaction'
  );

eval {
  local $dbh->{PrintError} = 0;
  $dbh->do(q{DROP TABLE tt});
  $dbh->commit();
};
$dbh->rollback();

$dbh->do(q{CREATE TABLE tt (blah numeric(5,2), foo text)});
my $sth = $dbh->prepare(qq{
			   SELECT * FROM tt WHERE FALSE
			  });
$sth->execute();

my @types = @{$sth->{pg_type}};

ok($types[0] eq 'numeric',
   'type numeric'
  );

ok($types[1] eq 'text',
   'type text'
  );

$sth->finish();
$dbh->rollback();
$dbh->disconnect();
