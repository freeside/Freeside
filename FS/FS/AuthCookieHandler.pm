package FS::AuthCookieHandler;
use base qw( Apache2::AuthCookie );

use strict;
use FS::UID qw( adminsuidsetup preuser_setup );
use FS::CurrentUser;

my $module = 'legacy'; #XXX i am set in a conf somehow?  or a config file

sub authen_cred {
  my( $self, $r, $username, $password ) = @_;

  unless ( _is_valid_user($username, $password) ) {
    warn "failed auth $username from ". $r->connection->remote_ip. "\n";
    return undef;
  }

  warn "authenticated $username from ". $r->connection->remote_ip. "\n";
  adminsuidsetup($username);

  FS::CurrentUser->new_session;

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
