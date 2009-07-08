package FS::TicketSystem::RT_Internal;

use strict;
use vars qw( @ISA $DEBUG );
use FS::UID qw(dbh);
use FS::CGI qw(popurl);
use FS::TicketSystem::RT_Libs;
use RT::CurrentUser;

@ISA = qw( FS::TicketSystem::RT_Libs );

$DEBUG = 1;

sub sql_num_customer_tickets {
  "( select count(*) from tickets
                     join links on ( tickets.id = links.localbase )
     where ( status = 'new' or status = 'open' or status = 'stalled' )
       and target = 'freeside://freeside/cust_main/' || custnum
   )";
}

sub baseurl {
  #my $self = shift;
  if ( $RT::URI::freeside::URL ) {
    $RT::URI::freeside::URL. '/rt/';
  } else {
    'http://you_need_to_set_RT_URI_freeside_URL_in_SiteConfig.pm/';
  }
}

#mapping/genericize??
#ShowConfigTab ModifySelf
sub access_right {
  my( $self, $session, $right ) = @_;

  #return '' unless $conf->config('ticket_system');
  return '' unless FS::Conf->new->config('ticket_system');

  $self->_web_external_auth($session)
    unless $session
    && $session->{'CurrentUser'};

  $session->{'CurrentUser'}->HasRight( Right  => $right,
                                       Object => $RT::System );
}

#shameless false laziness w/rt/html/autohandler to get logged into RT from afar
sub _web_external_auth {
  my( $self, $session ) = @_;

  my $user = $FS::CurrentUser::CurrentUser->username;

  $session->{'CurrentUser'} = RT::CurrentUser->new();

  warn "loading RT user for $user\n"
    if $DEBUG;

  $session->{'CurrentUser'}->Load($user);

  if ( ! $session->{'CurrentUser'}->Id() ) {

      # Create users on-the-fly

      warn "can't load RT user for $user; auto-creating\n"
        if $DEBUG;

      my $UserObj = RT::User->new( RT::CurrentUser->new('RT_System') );

      my ( $val, $msg ) = $UserObj->Create(
          %{ ref($RT::AutoCreate) ? $RT::AutoCreate : {} },
          Name  => $user,
          Gecos => $user,
      );

      if ($val) {

          # now get user specific information, to better create our user.
          my $new_user_info
              = RT::Interface::Web::WebExternalAutoInfo($user);

          # set the attributes that have been defined.
          # FIXME: this is a horrible kludge. I'm sure there's something cleaner
          foreach my $attribute (
              'Name',                  'Comments',
              'Signature',             'EmailAddress',
              'PagerEmailAddress',     'FreeformContactInfo',
              'Organization',          'Disabled',
              'Privileged',            'RealName',
              'NickName',              'Lang',
              'EmailEncoding',         'WebEncoding',
              'ExternalContactInfoId', 'ContactInfoSystem',
              'ExternalAuthId',        'Gecos',
              'HomePhone',             'WorkPhone',
              'MobilePhone',           'PagerPhone',
              'Address1',              'Address2',
              'City',                  'State',
              'Zip',                   'Country'
              )
          {
              #uhh, wrong root
              #$m->comp( '/Elements/Callback', %ARGS,
              #    _CallbackName => 'NewUser' );

              my $method = "Set$attribute";
              $UserObj->$method( $new_user_info->{$attribute} )
                  if ( defined $new_user_info->{$attribute} );
          }
          $session->{'CurrentUser'}->Load($user);
      }
      else {

         # we failed to successfully create the user. abort abort abort.
          delete $session->{'CurrentUser'};

          die "can't auto-create RT user"; #an error message would be nice :/
          #$m->abort() unless $RT::WebFallbackToInternalAuth;
          #$m->comp( '/Elements/Login', %ARGS,
          #    Error => loc( 'Cannot create user: [_1]', $msg ) );
      }
  }

  unless ( $session->{'CurrentUser'}->Id() ) {
      delete $session->{'CurrentUser'};

      die "can't auto-create RT user";
      #$user = $orig_user;
      # 
      #if ($RT::WebExternalOnly) {
      #    $m->comp( '/Elements/Login', %ARGS,
      #        Error => loc('You are not an authorized user') );
      #    $m->abort();
      #}
  }

}

1;

