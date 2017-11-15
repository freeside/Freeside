#!/usr/bin/perl

## example
# perl xmlrpc-customer_package-status.pl <pkgnum>
##  

use strict;
use Frontier::Client;
use Data::Dumper;

my $uri = new URI 'http://localhost:8008/';

my $server = new Frontier::Client ( 'url' => $uri );

my $result = $server->call(
  'FS.API.package_status',
    'secret'  => 'MySecretCode',
    'pkgnum' => $ARGV[0],
);

die $result->{'error'} if $result->{'error'};

print $result->{status};

print "\nAll Done\n";

exit;