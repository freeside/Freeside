#!/usr/bin/perl

use strict;
use Frontier::Client;
use Data::Dumper;

my $uri = new URI 'http://localhost:8008/';

my $server = new Frontier::Client ( 'url' => $uri );

my $result = $server->call(
  'FS.API.add_advertising_source',
    'secret' => 'MySecretCode',
    'source' => {
    		'referral' => 'API test referral',
    		'disabled' => '',
    		'agentnum' => '',
    		'title'    => 'API test title',
    	},
);

die $result->{'error'} if $result->{'error'};

print Dumper($result);

print "\nAll Done\n";

exit;