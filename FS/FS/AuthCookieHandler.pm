package FS::AuthCookieHandler;
use base qw( Apache2::AuthCookie );

use strict;
use FS::UID qw( adminsuidsetup preuser_setup );
use FS::CurrentUser;
use FS::Auth;

sub authen_cred {
  my( $self, $r, $username, $password ) = @_;

  if (!eval{preuser_setup();}) {
      return (undef,'no_preuser_setup');
  }

  my $info = {};

  my $sessionkey;
  unless ( $sessionkey = FS::Auth->authenticate($username, $password, $info) ) {
    warn "failed auth $username from ". $r->connection->remote_ip. "\n";
    return undef;
  }

  warn "authenticated $username from ". $r->connection->remote_ip. "\n";

  FS::CurrentUser->load_user( $username,
                              'autocreate' => FS::Auth->auth_class->autocreate,
                              %$info,
                            );

  FS::CurrentUser->new_session($sessionkey);
}

sub custom_errors {
    my ($self,$r,$auth_user,@args) = @_;
    my $auth_type = $r->auth_type;
    $auth_type->remove_cookie($r);
    my @allowed_errors = ['no_preuser_setup'];
    $r->subprocess_env('AuthCookieReason', $args[0] ~~ @allowed_errors ? $args[0] : 'bad_cookie');
    $auth_type->login_form($r);
}

sub authen_ses_key {
  my( $self, $r, $sessionkey ) = @_;

  if (!eval{preuser_setup();}) {
      return (undef,'no_preuser_setup');
  }

  my $curuser = FS::CurrentUser->load_user_session( $sessionkey );

  unless ( $curuser ) {
    warn "bad session $sessionkey from ". $r->connection->remote_ip. "\n";
    return undef;
  }

  my $new_sessionkey;
  unless ( $new_sessionkey = FS::Auth->verify_user( $curuser, $sessionkey ) ) {
    warn "bad verify_user $sessionkey from ". $r->connection->remote_ip. "\n";
    return undef;
  }
  if ($new_sessionkey ne $sessionkey && $new_sessionkey ne 1) {
    FS::CurrentUser->new_session($new_sessionkey);
    Apache2::AuthCookie->send_cookie($r, $new_sessionkey);
  }

  $curuser->username;
}

1;
