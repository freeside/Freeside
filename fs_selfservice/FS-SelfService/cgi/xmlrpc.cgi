#!/usr/bin/perl -Tw

use strict;
use XMLRPC::Transport::HTTP;
use XMLRPC::Lite; # for XMLRPC::Serializer
use FS::SelfService::XMLRPC;

my %typelookup = (
#not utf-8 safe#  base64 => [10, sub {$_[0] =~ /[^\x09\x0a\x0d\x20-\x7f]/}, 'as_base64'],
  dateTime => [35, sub {$_[0] =~ /^\d{8}T\d\d:\d\d:\d\d$/}, 'as_dateTime'],
  string => [40, sub {1}, 'as_string'],
);
my $serializer = new XMLRPC::Serializer(typelookup => \%typelookup);
 
XMLRPC::Transport::HTTP::CGI->dispatch_to('FS::SelfService::XMLRPC')
                            ->serializer($serializer)
                            ->handle;

