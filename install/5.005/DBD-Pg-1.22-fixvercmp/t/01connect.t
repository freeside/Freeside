use strict;
use DBI;
use Test::More;

if (defined $ENV{DBI_DSN}) {
  plan tests => 2;
} else {
  plan skip_all => 'cannot test without DB info';
}

my $dbh = DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS},
		       {RaiseError => 1, AutoCommit => 0}
		      );

ok((defined $dbh and $dbh->disconnect()),
   'connect with transaction'
  );

undef $dbh;
$dbh = DBI->connect($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS},
		    {RaiseError => 1, AutoCommit => 1});

ok((defined $dbh and $dbh->disconnect()),
   'connect without transaction'
  );

