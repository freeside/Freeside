package FS::AuthCookieHandler;
use base qw( Apache2::AuthCookie );

use strict;
use FS::UID qw( adminsuidsetup preuser_setup );
use FS::CurrentUser;
use FS::Auth;

#Apache 2.2 and below
sub useragent_ip {
  my( $self, $r ) = @_;
  $r->connection->remote_ip;
}

sub authen_cred {
  my( $self, $r, $username, $password ) = @_;

  preuser_setup();

  my $info = {};

  unless ( FS::Auth->authenticate($username, $password, $info) ) {
    warn "failed auth $username from ". $self->useragent_ip($r). "\n";
    return undef;
  }

  warn "authenticated $username from ". $self->useragent_ip($r). "\n";

  FS::CurrentUser->load_user( $username,
                              'autocreate' => FS::Auth->auth_class->autocreate,
                              %$info,
                            );

  FS::CurrentUser->new_session;
}

sub authen_ses_key {
  my( $self, $r, $sessionkey ) = @_;

  preuser_setup();

  my $curuser = FS::CurrentUser->load_user_session( $sessionkey );

  unless ( $curuser ) {
    warn "bad session $sessionkey from ". $self->useragent_ip($r). "\n";
    return undef;
  }

  $curuser->username;
}

1;
