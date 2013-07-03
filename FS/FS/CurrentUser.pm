package FS::CurrentUser;

use vars qw($CurrentUser $CurrentSession $upgrade_hack);

#not at compile-time, circular dependancey causes trouble
#use FS::Record qw(qsearchs);
#use FS::access_user;

$upgrade_hack = 0;

=head1 NAME

FS::CurrentUser - Package representing the current user (and session)

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CLASS METHODS

=over 4

=item load_user USERNAME

Sets the current user to the provided username

=cut

sub load_user {
  my( $class, $username, %opt ) = @_;

  if ( $upgrade_hack ) {
    return $CurrentUser = new FS::CurrentUser::BootstrapUser;
  }

  #return "" if $username =~ /^fs_(queue|selfservice)$/;

  #not the best thing in the world...
  eval "use FS::Record qw(qsearchs);";
  die $@ if $@;
  eval "use FS::access_user;";
  die $@ if $@;

  my %hash = ( 'username' => $username,
               'disabled' => '',
             );

  $CurrentUser = qsearchs('access_user', \%hash) and return $CurrentUser;

  die "unknown user: $username" unless $opt{'autocreate'};

  $CurrentUser = new FS::access_user \%hash;
  $CurrentUser->set($_, $opt{$_}) foreach qw( first last );
  my $error = $CurrentUser->insert;
  die $error if $error; #better way to handle this error?

  my $template_user =
    $opt{'template_user'}
      || FS::Conf->new->config('external_auth-access_group-template_user');

  if ( $template_user ) {

    my $tmpl_access_user =
       qsearchs('access_user', { 'username' => $template_user } );

    if ( $tmpl_access_user ) {
      eval "use FS::access_usergroup;";
      die $@ if $@;

      foreach my $tmpl_access_usergroup
                ($tmpl_access_user->access_usergroup) {
        my $access_usergroup = new FS::access_usergroup {
          'usernum'  => $CurrentUser->usernum,
          'groupnum' => $tmpl_access_usergroup->groupnum,
        };
        my $error = $access_usergroup->insert;
        if ( $error ) {
          #shouldn't happen, but seems better to proceed than to die
          warn "error inserting access_usergroup: $error";
        };
      }

    } else {
      warn "template username $template_user not found\n";
    }

  } else {
    warn "no access template user for autocreated user $username\n";
  }

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

Minimal docs

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

