#!/usr/bin/perl

use strict;
use Frontier::Client;
use Data::Dumper;

my $uri = new URI 'http://localhost:8080/';

my $server = new Frontier::Client ( 'url' => $uri );

my $result = $server->call('phonenum_balance', 'phonenum' => '9567566022', );

#die $result->{'error'} if $result->{'error'};

print Dumper($result);

1;
