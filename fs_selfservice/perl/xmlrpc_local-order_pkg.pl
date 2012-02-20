#!/usr/bin/perl

use strict;
use Frontier::Client;
use Data::Dumper;
use Data::Faker;

my $server = new Frontier::Client (
        url => 'http://localhost:8080/selfservice/xmlrpc.cgi',
);

my $login = $server->call('FS.ClientAPI_XMLRPC.login', {
  'username' => 'yokn',
  'domain'   => 'example1.com',
  'password' => 'RUPUQC8H',
} );

die $login->{'error'} if $login->{'error'};

my $session_id = $login->{'session_id'};

my $faker = new Data::Faker;

my $result = $server->call('FS.ClientAPI_XMLRPC.order_pkg', {
  'session_id' => $session_id,
  'pkgpart'    => 3,
  'username'   => $faker->username,
  'password'   => '123456',
});

#print Dumper($result);
die $result->{'error'} if $result->{'error'};

warn Dumper($result);

1;
