package FS::XMLRPC_Lite;

use XMLRPC::Lite;

use XMLRPC::Transport::HTTP;

#XXX submit patch to SOAP::Lite

package XMLRPC::Transport::HTTP::Server;

@XMLRPC::Transport::HTTP::Server::ISA = qw(SOAP::Transport::HTTP::Server);

sub initialize; *initialize = \&XMLRPC::Server::initialize;
sub make_fault; *make_fault = \&XMLRPC::Transport::HTTP::CGI::make_fault;
sub make_response; *make_response = \&XMLRPC::Transport::HTTP::CGI::make_response;

1;
