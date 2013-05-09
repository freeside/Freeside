package FS::Auth::internal;
#use base qw( FS::Auth );

use strict;
use Crypt::Eksblowfish::Bcrypt qw(bcrypt_hash en_base64 de_base64);
use FS::Record qw( qsearchs );
use FS::access_user;

sub authenticate {
  my($self, $username, $check_password ) = @_;

  my $access_user =
    ref($username) ? $username
                   : qsearchs('access_user', { 'username' => $username,
                                               'disabled' => '',
                                             }
                             )
    or return 0;

  if ( $access_user->_password_encoding eq 'bcrypt' ) {

    my( $cost, $salt, $hash ) = split(',', $access_user->_password);

    my $check_hash = en_base64( bcrypt_hash( { key_nul => 1,
                                               cost    => $cost,
                                               salt    => de_base64($salt),
                                             },
                                             $check_password
                                           )
                              );

    $hash eq $check_hash;

  } else { 

    return 0 if $access_user->_password eq 'notyet'
             || $access_user->_password eq '';

    $access_user->_password eq $check_password;

  }

}

sub change_password {
  my($self, $access_user, $new_password) = @_;

  $self->change_password_fields( $access_user, $new_password );

  $access_user->replace;

}

sub change_password_fields {
  my($self, $access_user, $new_password) = @_;

  $access_user->_password_encoding('bcrypt');

  my $cost = 8;

  my $salt = pack( 'C*', map int(rand(256)), 1..16 );

  my $hash = bcrypt_hash( { key_nul => 1,
                            cost    => $cost,
                            salt    => $salt,
                          },
                          $new_password,
                        );

  $access_user->_password(
    join(',', $cost, en_base64($salt), en_base64($hash) )
  );

}

1;
