package iZoomOnlineProvisionService;

use strict;

#BEGIN { push @INC, '/usr/lib/perl/5.8.8/' };
use FS::SelfService qw( bulk_processrow check_username agent_login );
   
=begin WSDL

_IN agent_username $string agent username
_IN agent_password $string agent password
_IN agent_custid $string customer id in agent system
_IN username $string customer service username
_IN password $string customer service password
_IN daytime $string phone number
_IN first $string first name
_IN last $string last name
_IN address1 $string address line 1
_IN address2 $string address line 2
_IN city $string city
_IN state $string state
_IN zip $string zip
_IN pkg $string package name
_IN action $string one of (R|P|D|S)(reconcile, provision, provision with disk, send disk)
_IN adjourn $string day to terminate service
_IN mobile $string mobile phone
_IN sms $string (T|F) acceptable to send SMS messages to mobile?
_IN ship_addr1 $string shipping address line 1
_IN ship_addr2 $string shipping address line 2 
_IN ship_city $string shipping address city
_IN ship_state $string shipping address state
_IN ship_zip $string shipping address zip
_RETURN @string array [status, message]. status is one of OK, ERR

=cut

my $DEBUG = 0;

sub Provision {
  my $class = shift;

  my $session = agent_login( map { $_ => shift @_ } qw( username password ) );
  return [ 'ERR', $session->{error} ] if $session->{error};

  my $result =
    bulk_processrow( session_id => $session->{session_id}, row => [ @_ ] );
    
  return $result->{error} ? [ 'ERR', $result->{error} ]
                          : [ 'OK',  $result->{message} ];
}

=begin WSDL

_IN agent_username $string agent username
_IN agent_password $string agent password
_IN username $string customer service username
_IN domain $string user domain name
_RETURN @string [OK|ERR] 

=cut
sub CheckUserName {
  my $class = shift;

  my $session = agent_login( map { $_ => shift @_ } qw( username password ) );
  return [ 'ERR', $session->{error} ] if $session->{error};

  my $result = check_username( session_id => $session->{session_id},
                               map { $_ => shift @_ } qw( user domain )
               );
    
  return $result->{error} ? [ 'ERR', $result->{error} ]
                          : [ 'OK',  $result->{message} ];
}

1;
