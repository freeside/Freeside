#!/usr/bin/perl

use strict;
use Frontier::Client;
use Data::Dumper;;

my $server = new Frontier::Client (
        url => 'http://localhost/selfservice/xmlrpc.cgi',
);

my $result = $server->call('FS.SelfService.XMLRPC.login',
  'username' => '4155551212',
  'password' => '5454',
  'domain'   => 'svc_phone',
);

#print Dumper($result);
die $result->{'error'} if $result->{'error'};

my $session_id = $result->{'session_id'};
warn "logged in with session_id $session_id\n";

my $t_result = $server->call('FS.SelfService.XMLRPC.create_ticket',
  'session_id' => $session_id,
  'queue'      => 3, #otherwise defaults to ticket_system-selfservice_queueid
                     #or ticket_system-default_queueid
  'requestor'  => 'harveylala@example.com',
  'cc'         => 'chiquitabanana@example.com',
  'subject'    => 'Chiquita keeps sitting on me',
  'message'    => 'Is there something you can do about this?<BR><BR>She keeps waking me up!  <A HREF="http://linktest.freeside.biz/hi">link test</A>',
  'mime_type'  => 'text/html',
);

die $t_result->{'error'} if $t_result->{'error'};

warn Dumper($t_result);

my $ticket_id = $t_result->{'ticket_id'};
warn "ticket $ticket_id created\n";

1;
