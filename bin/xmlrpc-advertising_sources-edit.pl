#!/usr/bin/perl

use strict;
use Frontier::Client;
use Data::Dumper;

my $uri = new URI 'http://localhost:8008/';

my $server = new Frontier::Client ( 'url' => $uri );

my $result = $server->call(
  'FS.API.edit_advertising_source',
    'secret' => 'MySecretCode',
    'refnum' => '4',
    'source' => {
    		'referral' => 'Edit referral',
    		'title'    => 'Edit Referral title',
    		#'disabled' => 'Y',
    		#'disabled' => '',
    		#'agentnum' => '2',
    	},
);

die $result->{'error'} if $result->{'error'};

print Dumper($result);

print "\nAll Done\n";

exit;