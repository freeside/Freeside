#!/usr/bin/perl
#
# xmlrpc-order_pkg.pl username password

use strict;
use Frontier::Client;
use Data::Dumper;

my( $u, $p, $custnum ) = ( @ARGV );
my $userinfo = $u.':'.$p;

my $uri = new URI 'http://localhost/freeside/misc/xmlrpc.cgi';
$uri->userinfo( $userinfo );

my $server = new Frontier::Client ( 'url' => $uri );

my $result = $server->call('Maestro.order_pkg',
  {
    'custnum' => 8,
    'pkgpart' => 3,
    'id'      => $$, #unique
    'title'   => 'John Q. Public', #'name' also works
                                   #(turn off global_unique-pbx_title)
  },
);

#die $result->{'error'} if $result->{'error'};

print Dumper($result);

1;
