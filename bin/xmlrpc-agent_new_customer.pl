#!/usr/bin/perl
#
# xmlrpc-agent_new_customer.pl username password

use strict;
use Frontier::Client;
use Data::Dumper;

my( $username, $password ) = ( @ARGV );

my $uri = new URI 'http://localhost/selfservice/xmlrpc.cgi';

my $server = new Frontier::Client ( 'url' => $uri );


###
#   login
###

my $login_result = $server->call('FS.SelfService.XMLRPC.agent_login',
  {
    'username' => $username,
    'password' => $username,
  }
);

die $login_result->{'error'} if $login_result->{'error'};

my $session_id = $login_result->{'session_id'};
warn "logged in w/session_id $session_id\n";


###
#   new_customer
###

my $result = $server->call('FS.SelfService.XMLRPC.new_customer',
  {
    'session_id'     => $session_id,
    #customer informaiton
    'first'          => 'Tofu',
    'last'           => 'Beast',
    'address1'       => '1234 Soybean Ln.',
    'city'           => 'Tofutown',
    'state'          => 'CA',
    'zip'            => '54321',
    'country'        => 'US',
    'invoicing_list' => 'tofu@example.com',
    #billing information
    'payby'          => 'CARD',
    'payinfo'        => '4111111111111111',
    'paycvv'         => '123',
    'paydate'        => '11/2012',
    #package information
    'pkgpart'        => '2',
    'username'       => 'tofu',
    '_password'      => 's33kret',
  }
);

die $result->{'error'} if $result->{'error'};

my $custnum = $result->{'custnum'};
warn "added new customer w/custnum $custnum\n";


###
#   logout
###

my $logout_result = $server->call('FS.SelfService.XMLRPC.agent_logout',
  {
    'session_id' => $session_id,
  }
);

die $logout_result->{'error'} if $logout_result->{'error'};
warn "logged out\n";

1;
