package FS::access_user::external_auth;
use base qw( FS::access_user );

use strict;

sub authenticate {
  my( $username, $check_password ) = @_;

  #magic happens here

  if ( $auth_good ) { #verbose for clarity
    return 1;
  } else {
    return 0;
  }

}

#omitting these subroutines will eliminate 

#sub create_user {
#

#sub change_password {
#}

1;
