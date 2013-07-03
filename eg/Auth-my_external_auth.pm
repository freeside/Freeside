package FS::Auth::my_external_auth;
use base qw( FS::Auth::external ); #need to inherit from ::external

use strict;

sub authenticate {
  my($self, $username, $check_password, $info ) = @_;

  #your magic happens here

  if ( $auth_good ) {

    #optionally return a real name
    #$info->{'first'} = "Jean";
    #$info->{'last'}  = "D'eau";

    #optionally return a template username to copy access groups from that user
    #$info->{'template_user'} = 'username';

    return 1;

  } else {
    return 0;
  }

}

1;
