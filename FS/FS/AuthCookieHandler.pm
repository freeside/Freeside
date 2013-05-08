package FS::AuthCookieHandler;
use base qw( Apache2::AuthCookie );

use strict;
use FS::UID qw( adminsuidsetup preuser_setup );
use FS::CurrentUser;
use FS::Auth;

sub authen_cred {
  my( $self, $r, $username, $password ) = @_;

  preuser_setup();

  unless ( _is_valid_user($username, $password) ) {
    warn "failed auth $username from ". $r->connection->remote_ip. "\n";
    return undef;
  }

  warn "authenticated $username from ". $r->connection->remote_ip. "\n";

  FS::CurrentUser->load_user($username);

  FS::CurrentUser->new_session;
}

sub _is_valid_user {
  my( $username, $password ) = @_;

  FS::Auth->authenticate($username, $password);
}

sub authen_ses_key {
  my( $self, $r, $sessionkey ) = @_;

  preuser_setup();

  my $curuser = FS::CurrentUser->load_user_session( $sessionkey );

  unless ( $curuser ) {
    warn "bad session $sessionkey from ". $r->connection->remote_ip. "\n";
    return undef;
  }

  $curuser->username;
}

1;
