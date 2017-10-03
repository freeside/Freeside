#!/usr/bin/perl

use strict;
use Frontier::Client;
use Data::Dumper;

my $uri = new URI 'http://localhost:8008/';

my $server = new Frontier::Client ( 'url' => $uri );

my $result = $server->call(
  'FS.API.list_advertising_sources',
    'secret'  => 'MySecretCode',
);

die $result->{'error'} if $result->{'error'};

print Dumper($result);

print "\nAll Done\n";

exit;