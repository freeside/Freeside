package FS::CurrentUser;

use vars qw($CurrentUser $upgrade_hack);

#not at compile-time, circular dependancey causes trouble
#use FS::Record qw(qsearchs);
#use FS::access_user;

$upgrade_hack = 0;

=head1 NAME

FS::CurrentUser - Package representing the current user

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

sub load_user {
  my( $class, $user ) = @_; #, $pass

  if ( $upgrade_hack ) {
    return $CurrentUser = new FS::CurrentUser::BootstrapUser;
  }

  #return "" if $user =~ /^fs_(queue|selfservice)$/;

  #not the best thing in the world...
  eval "use FS::Record qw(qsearchs);";
  die $@ if $@;
  eval "use FS::access_user;";
  die $@ if $@;

  $CurrentUser = qsearchs('access_user', {
    'username' => $user,
    #'_password' =>
    'disabled' => '',
  } );

  die "unknown user: $user" unless $CurrentUser; # or bad password

  $CurrentUser;
}

=item new_session

Creates a new session for the current user and returns the session key

=cut

use vars qw( @saltset );
@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '+' , '/' );

sub new_session {
  my( $class ) = @_;

  #not the best thing in the world...
  eval "use FS::access_user_session;";
  die $@ if $@;

  my $sessionkey = join('', map $saltset[int(rand(scalar @saltset))], 0..39);

  my $access_user_session = new FS::access_user_session {
    'sessionkey' => $sessionkey,
    'usernum'    => $CurrentUser->usernum,
    'start_date' => time,
  };
  my $error = $access_user_session->insert;
  die $error if $error;

  return $sessionkey;

}

=item load_user_session SESSION_KEY

Sets the current user via the provided session key

=cut

sub load_user_session {
  my( $class, $sessionkey ) = @_;

  #not the best thing in the world...
  eval "use FS::Record qw(qsearchs);";
  die $@ if $@;
  eval "use FS::access_user_session;";
  die $@ if $@;

  $CurrentSession = qsearchs('access_user_session', {
    'sessionkey' => $sessionkey,
    #XXX check for timed out but not-yet deleted sessions here
  }) or return '';

  $CurrentSession->touch_last_date;

  $CurrentUser = $CurrentSession->access_user;

}

=head1 BUGS

Creepy crawlies

=head1 SEE ALSO

=cut

package FS::CurrentUser::BootstrapUser;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  bless ($self, $class);
}

sub AUTOLOAD { 1 };

1;

