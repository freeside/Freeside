# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;

use Test::More tests => 5;
BEGIN { use_ok('Net::Whois::Raw',qw( whois )) };

my @domains = qw( 
	yahoo.com
	freshmeat.net
	freebsd.org
	ucsb.edu
);

print "The following tests requires internet connection...\n";

foreach my $domain ( @domains ) {
	my $txt = whois( $domain );
	ok($txt =~ /$domain/i, "$domain resolved");
}

