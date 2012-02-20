#!/usr/bin/perl

use strict;
use Frontier::Client;
use Data::Dumper;
use Data::Faker;

my $server = new Frontier::Client (
        url => 'http://localhost:8080/selfservice/xmlrpc.cgi',
);

my $faker = new Data::Faker;

my $result = $server->call('FS.ClientAPI_XMLRPC.new_agent', {
  'agent'    => $faker->company,
  'username' => $faker->username,
  'password' => '12345',
});

#print Dumper($result);
die $result->{'error'} if $result->{'error'};

warn Dumper($result);

1;
