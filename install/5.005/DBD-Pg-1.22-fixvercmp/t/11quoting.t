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

my %tests = (
	     one=>["'", "'\\" . sprintf("%03o", ord("'")) . "'"],
	     two=>["''", "'" . ("\\" . sprintf("%03o", ord("'")))x2 . "'"],
	     three=>["\\", "'\\" . sprintf("%03o", ord("\\")) . "'"],
	     four=>["\\'", sprintf("'\\%03o\\%03o'", ord("\\"), ord("'"))],
	     five=>["\\'?:", sprintf("'\\%03o\\%03o?:'", ord("\\"), ord("'"))],
	    );

foreach my $test (keys %tests) {
  my ($unq, $quo, $ref);

  $unq = $tests{$test}->[0];
  $ref = $tests{$test}->[1];
  $quo = $dbh->quote($unq);

  ok($quo eq $ref,
     "$test: $unq -> expected $quo got $ref"
    );
}

# Make sure that SQL_BINARY doesn't work.
#    eval { $dbh->quote('foo', { TYPE => DBI::SQL_BINARY })};
eval {
  local $dbh->{PrintError} = 0;
  $dbh->quote('foo', DBI::SQL_BINARY);
};
ok($@ && $@ =~ /Use of SQL_BINARY invalid in quote/,
   'SQL_BINARY'
);

ok($dbh->disconnect(),
   'disconnect'
  );
