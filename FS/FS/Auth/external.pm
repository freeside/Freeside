packages FS::Auth::external;
#use base qw( FS::Auth );

use strict;

sub autocreate {
  my $username = shift;
  my $access_user = new FS::access_user {
    'username' => $username,
    #'_password' => #XXX something random so a switch to internal auth doesn't
                    #let people on?
  };
  my $error = $access_user->insert;
  #die $error if $error;
}

1;

