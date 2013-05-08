package FS::Auth::my_external_auth;
use base qw( FS::Auth::external ); #need to inherit from ::external

use strict;

sub authenticate {
  my($self, $username, $check_password ) = @_;

  #magic happens here

  if ( $auth_good ) { #verbose for clarity
    return 1;
  } else {
    return 0;
  }

}

#omitting these subroutines will eliminate those options from the UI

#sub create_user {
#

#sub change_password {
#}

1;
