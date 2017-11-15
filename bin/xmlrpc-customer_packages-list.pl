#!/usr/bin/perl

## example
# perl xmlrpc-customer_packages-list.pl <custnum>
##  

use strict;
use Frontier::Client;
use Data::Dumper;

my $uri = new URI 'http://localhost:8008/';

my $server = new Frontier::Client ( 'url' => $uri );

my $result = $server->call(
  'FS.API.list_customer_packages',
    'secret'  => 'MySecretCode',
    'custnum' => $ARGV[0],
);

die $result->{'error'} if $result->{'error'};

my @packages = @{$result->{packages}};

print Dumper(@packages);

print "\n total: " . scalar @packages;

print "\nAll Done\n";

exit;