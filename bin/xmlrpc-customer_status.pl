#!/usr/bin/perl
#
# xmlrpc-customer_status.pl username password custnum

use strict;
use Frontier::Client;
use Data::Dumper;

my( $u, $p, $custnum ) = ( @ARGV );
my $userinfo = $u.':'.$p;

my $uri = new URI 'http://localhost/freeside/misc/xmlrpc.cgi';
$uri->userinfo( $userinfo );

my $server = new Frontier::Client ( 'url' => $uri );

my $result = $server->call('Maestro.customer_status', $custnum );

#die $result->{'error'} if $result->{'error'};

print Dumper($result);

1;
