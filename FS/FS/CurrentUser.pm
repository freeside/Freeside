package FS::CurrentUser;

use vars qw($CurrentUser);

#not at compile-time, circular dependancey causes trouble
#use FS::Record qw(qsearchs);
#use FS::access_user;

=head1 NAME

FS::CurrentUser - Package representing the current user

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

sub load_user {
  my( $class, $user ) = @_; #, $pass

  #XXX remove me at some point
  return "" if $user =~ /^fs_(queue|selfservice)$/;

  #not the best thing in the world...
  eval "use FS::Record qw(qsearchs);";
  die $@ if $@;
  eval "use FS::access_user;";
  die $@ if $@;

  $CurrentUser = qsearchs('access_user', {
    'username' => $user,
    #'_password' =>
  } );

  die "unknown user: $user" unless $CurrentUser; # or bad password

  $CurrentUser;
}

=head1 BUGS

Creepy crawlies

=head1 SEE ALSO

=cut

1;

