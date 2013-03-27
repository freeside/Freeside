package FS::access_user::legacy;
use base qw( FS::access_user ); #::internal ?

use strict;

sub authenticate {
  my( $username, $check_password ) = @_;


}

sub change_password {
}

1;
