#!/usr/bin/perl

use strict;
use Frontier::Client;
use Data::Dumper;

my $server = new Frontier::Client (
	url => 'http://user:pass@freesidehost/misc/xmlrpc.cgi',
);

#my $method = 'cust_main.smart_search';
#my @args = (search => '1');

my $method = 'Record.qsearch';
my @args = (cust_main => { });

my $result = $server->call($method, @args);

if (ref($result) eq 'ARRAY') {
  print "Result:\n";
  print Dumper(@$result);
}

