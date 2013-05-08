package FS::Auth::internal;
#use base qw( FS::Auth );

use strict;
use Crypt::Eksblowfish::Bcrypt qw(bcrypt_hash);
use FS::Record qw( qsearchs );
use FS::access_user;

sub authenticate {
  my($self, $username, $check_password ) = @_;

  my $access_user = qsearchs('access_user', { 'username' => $username,
                                              'disabled' => '',
                                            }
                            )
    or return 0;

  if ( $access_user->_password_encoding eq 'bcrypt' ) {

    my( $cost, $salt, $hash ) = split(',', $access_user->_password);

    my $check_hash = bcrypt_hash( { key_nul => 1,
                                    cost    => $cost,
                                    salt    => $salt,
                                  },
                                  $check_password
                                );

    $hash eq $check_hash;

  } else { 

    return 0 if $access_user->_password eq 'notyet'
             || $access_user->_password eq '';

    $access_user->_password eq $check_password;

  }

}

#sub change_password {
#}

1;
