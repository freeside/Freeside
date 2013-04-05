package FS::AuthCookieHandler;
use base qw( Apache2::AuthCookie );

use strict;
use Digest::SHA qw( sha1_hex );
use FS::UID qw( adminsuidsetup );

my $secret = "XXX temporary"; #XXX move to a DB session with random number as key

my $module = 'legacy'; #XXX i am set in a conf somehow?  or a config file

sub authen_cred {
  my( $self, $r, $username, $password ) = @_;

  if ( _is_valid_user($username, $password) ) {
      warn "authenticated $username from ". $r->connection->remote_ip. "\n";
      adminsuidsetup($username);
      my $session_key =
        $username . '::' . sha1_hex( $username, $secret );
      return $session_key;
  } else {
      warn "failed authentication $username from ". $r->connection->remote_ip. "\n";
  }

  return undef; #?
}

sub _is_valid_user {
  my( $username, $password ) = @_;
  my $class = 'FS::Auth::'.$module;

  #earlier?
  eval "use $class;";
  die $@ if $@;

  $class->authenticate($username, $password);

}

sub authen_ses_key {
  my( $self, $r, $session_key ) = @_;

  my ($username, $mac) = split /::/, $session_key;

  if ( sha1_hex( $username, $secret ) eq $mac ) {
    adminsuidsetup($username);
    return $username;
  } else {
    warn "bad session $session_key from ". $r->connection->remote_ip. "\n";
  }

  return undef;

}

1;
