package FS::Auth::legacy;
#use base qw( FS::Auth ); #::internal ?

use strict;
use Apache::Htpasswd;

#substitute in?  we're trying to make it go away...
my $htpasswd_file = '/usr/local/etc/freeside/htpasswd';

sub authenticate {
  my($self, $username, $check_password ) = @_;

  Apache::Htpasswd->new( { passwdFile => $htpasswd_file,
                           ReadOnly   => 1,
                         }
    )->htCheckPassword($username, $check_password);
}

#don't support this in legacy?  change in both htpasswd and database like 3.x
# for easier transitioning?  hoping its really only me+employees that have a
# mismatch in htpasswd vs access_user, so maybe that's not necessary
#sub change_password {
#}

1;
