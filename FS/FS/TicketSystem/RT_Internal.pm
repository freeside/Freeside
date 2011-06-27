package FS::TicketSystem::RT_Internal;

use strict;
use vars qw( @ISA $DEBUG $me );
use Data::Dumper;
use MIME::Entity;
use FS::UID qw(dbh);
use FS::CGI qw(popurl);
use FS::TicketSystem::RT_Libs;

@ISA = qw( FS::TicketSystem::RT_Libs );

$DEBUG = 0;
$me = '[FS::TicketSystem::RT_Internal]';

sub sql_num_customer_tickets {
  "( select count(*) from Tickets
                     join Links on ( Tickets.id = Links.LocalBase )
     where ( Status = 'new' or Status = 'open' or Status = 'stalled' )
       and Target = 'freeside://freeside/cust_main/' || custnum
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

  return '' unless FS::Conf->new->config('ticket_system');

  $session = $self->session($session);

  #warn "$me access_right: CurrentUser ". $session->{'CurrentUser'}. ":\n".
  #     ( $DEBUG>1 ? Dumper($session->{'CurrentUser'}) : '' )
  #  if $DEBUG > 1;

  $session->{'CurrentUser'}->HasRight( Right  => $right,
                                       Object => $RT::System );
}

sub session {
  my( $self, $session ) = @_;

  if ( $session && $session->{'Current_User'} ) {
    warn "$me session: using existing session and CurrentUser: \n".
         Dumper($session->{'CurrentUser'})
      if $DEBUG;
 } else {
    warn "$me session: loading session and CurrentUser\n" if $DEBUG > 1;
    $session = $self->_web_external_auth($session);
  }

  $session;
}

my $firsttime = 1;

sub init {
  my $self = shift;
  if ( $firsttime ) {

    # this part only needs to be done once
    warn "$me init: loading RT libraries\n" if $DEBUG;
    eval '
      use lib ( "/opt/rt3/local/lib", "/opt/rt3/lib" );
      use RT;

      #for web external auth...
      use RT::Interface::Web;
    ';
    die $@ if $@;

    warn "$me init: loading RT config\n" if $DEBUG;
    {
      local $SIG{__DIE__};
      eval 'RT::LoadConfig();';
    }
    die $@ if $@;

    $firsttime = 0;
  }

  # this needs to be done on each fork
  warn "$me init: initializing RT\n" if $DEBUG;
  {
    local $SIG{__DIE__};
    eval 'RT::Init("NoSignalHandlers"=>1);';
  }
  die $@ if $@;

  warn "$me init: complete" if $DEBUG;
}

=item customer_tickets CUSTNUM [ LIMIT ] [ PRIORITYVALUE ]

Replacement for the one in RT_External so that we can access custom fields 
properly.

=cut

sub _customer_tickets_search {
  my ( $self, $custnum, $limit, $priority ) = @_;

  $custnum =~ /^\d+$/ or die "invalid custnum: $custnum";
  $limit =~ /^\d+$/ or die "invalid limit: $limit";

  my $session = $self->session();
  my $CurrentUser = $session->{CurrentUser} 
    or die "unable to create an RT session";

  my $Tickets = RT::Tickets->new($CurrentUser);

  my $rtql = "MemberOf = 'freeside://freeside/cust_main/$custnum'";

  if ( defined( $priority ) ) {
    my $custom_priority = FS::Conf->new->config('ticket_system-custom_priority_field');
    $rtql .= " AND CF.{$custom_priority} = '$priority'";
  }

  $rtql .= ' AND ( ' .
           join(' OR ', map { "Status = '$_'" } $self->statuses) .
           ' )';

  $Tickets->FromSQL($rtql);

  $Tickets->RowsPerPage($limit);

  return $Tickets;
}

sub customer_tickets {
  my $Tickets = _customer_tickets_search(@_);

  my $conf = FS::Conf->new;
  my $priority_order =
    $conf->exists('ticket_system-priority_reverse') ? 'ASC' : 'DESC';
  my $custom_priority = 
    $conf->config('ticket_system-custom_priority_field') || '';

  my @order_by;
  my $ss_priority = selfservice_priority();
  push @order_by, { FIELD => "CF.{$ss_priority}", ORDER => $priority_order }
    if $ss_priority;
  push @order_by,
    { FIELD => 'Priority', ORDER => $priority_order },
    { FIELD => 'Id',       ORDER => 'DESC' },
  ;

  $Tickets->OrderByCols(@order_by);

  my @tickets;
  while ( my $t = $Tickets->Next ) {
    push @tickets, _ticket_info($t);
  }
  return \@tickets;
}

sub num_customer_tickets {
  my $Tickets = _customer_tickets_search(@_);
  return $Tickets->CountAll;
}

sub _ticket_info {
  # Takes an RT::Ticket; returns a hashref of the ticket's fields, including 
  # custom fields.  Also returns custom and selfservice priority values as 
  # _custom_priority and _selfservice_priority.
  my $t = shift;

  my $custom_priority = 
    FS::Conf->new->config('ticket_system-custom_priority_field') || '';
  my $ss_priority = selfservice_priority();

  my %ticket_info;
  foreach my $name ( $t->ReadableAttributes ) {
    # lowercase names, and skip attributes with non-scalar values
    $ticket_info{lc($name)} = $t->$name if !ref($t->$name);
  }
  $ticket_info{'owner'} = $t->OwnerObj->Name;
  $ticket_info{'queue'} = $t->QueueObj->Name;
  foreach my $CF ( @{ $t->CustomFields->ItemsArrayRef } ) {
    my $name = 'CF.{'.$CF->Name.'}';
    $ticket_info{$name} = $t->CustomFieldValuesAsString($CF->Id);
  }
  # make this easy to find
  if ( $custom_priority ) {
    $ticket_info{'_custom_priority'} = $ticket_info{"CF.{$custom_priority}"};
  }
  if ( $ss_priority ) {
    $ticket_info{'_selfservice_priority'} = $ticket_info{"CF.{$ss_priority}"};
  }
  return \%ticket_info;
}

=item create_ticket SESSION_HASHREF, OPTION => VALUE ...

Class method.  Creates a ticket.  If there is an error, returns the scalar
error, otherwise returns the newly created RT::Ticket object.

Accepts the following options:

=over 4

=item queue

Queue name or Id

=item subject

Ticket subject

=item requestor

Requestor email address or arrayref of addresses

=item cc

Cc: email address or arrayref of addresses

=item message

Ticket message

=item mime_type

MIME type to use for message.  Defaults to text/plain.  Specifying text/html
can be useful to use HTML markup in message.

=item custnum

Customer number (see L<FS::cust_main>) to associate with ticket.

=item svcnum

Service number (see L<FS::cust_svc>) to associate with ticket.  Will also
associate the customer who has this service (unless the service is unlinked).

=back

=cut

sub create_ticket {
  my($self, $session, %param) = @_;

  $session = $self->session($session);

  my $Queue = RT::Queue->new($session->{'CurrentUser'});
  $Queue->Load( $param{'queue'} );

  my $req = ref($param{'requestor'})
              ? $param{'requestor'}
              : ( $param{'requestor'} ? [ $param{'requestor'} ] : [] );

  my $cc = ref($param{'cc'})
             ? $param{'cc'}
             : ( $param{'cc'} ? [ $param{'cc'} ] : [] );

  my $mimeobj = MIME::Entity->build(
    'Data' => $param{'message'},
    'Type' => ( $param{'mime_type'} || 'text/plain' ),
  );

  my %ticket = (
    'Queue'     => $Queue->Id,
    'Subject'   => $param{'subject'},
    'Requestor' => $req,
    'Cc'        => $cc,
    'MIMEObj'   => $mimeobj,
  );
  warn Dumper(\%ticket) if $DEBUG > 1;

  my $Ticket = RT::Ticket->new($session->{'CurrentUser'});
  my( $id, $Transaction, $ErrStr );
  {
    local $SIG{__DIE__};
    ( $id, $Transaction, $ErrStr ) = $Ticket->Create( %ticket );
  }
  return $ErrStr if $id == 0;

  warn "ticket got id $id\n" if $DEBUG;

  #XXX check errors adding custnum/svcnum links (put it in a transaction)...
  # but we do already know they're good

  if ( $param{'custnum'} ) {
    my( $val, $msg ) = $Ticket->_AddLink(
     'Type'   => 'MemberOf',
     'Target' => 'freeside://freeside/cust_main/'. $param{'custnum'},
    );
  }

  if ( $param{'svcnum'} ) {
    my( $val, $msg ) = $Ticket->_AddLink(
     'Type'   => 'MemberOf',
     'Target' => 'freeside://freeside/cust_svc/'. $param{'svcnum'},
    );
  }

  $Ticket;
}

=item get_ticket SESSION_HASHREF, OPTION => VALUE ...

Class method. Retrieves a ticket. If there is an error, returns the scalar
error. Otherwise, currently returns a slightly tricky data structure containing
the ticket's attributes, a list of the linked customers, each transaction's 
content, description, and create time.

Accepts the following options:

=over 4

=item ticket_id 

The ticket id

=back

=cut

sub get_ticket {
  my($self, $session, %param) = @_;

  $session = $self->session($session);

  my $Ticket = RT::Ticket->new($session->{'CurrentUser'});
  my $ticketid = $Ticket->Load( $param{'ticket_id'} );
  return 'Could not load ticket' unless $ticketid;

  my @custs = ();
  foreach my $link ( @{ $Ticket->Customers->ItemsArrayRef } ) {
    my $cust = $link->Target;
    push @custs, $1 if $cust =~ /\/(\d+)$/;
  }

  my @txns = ();
  my $transactions = $Ticket->Transactions;
  while ( my $transaction = $transactions->Next ) {
    my $t = { created => $transaction->Created,
	content => $transaction->Content,
	description => $transaction->Description,
	type => $transaction->Type,
    };
    push @txns, $t;
  }

  { txns => [ @txns ],
    custs => [ @custs ],
    fields => _ticket_info($Ticket),
  };
}

=item get_ticket_object SESSION_HASHREF, OPTION => VALUE...

Class method.  Retrieve the RT::Ticket object with the specified 
ticket_id.  If custnum is supplied, will also check that the object 
is a member of that customer.  If there is no ticket or the custnum 
check fails, returns nothing.  The meaning of that case is 
"to this customer, the ticket does not exist".

Options:

=over 4

=item ticket_id

=item custnum

=back

=cut

sub get_ticket_object {
  my $self = shift;
  my ($session, %opt) = @_;
  $session = $self->session(shift);
  my $Ticket = RT::Ticket->new($session->{CurrentUser});
  $Ticket->Load($opt{'ticket_id'});
  return if ( !$Ticket->id );
  my $custnum = $opt{'custnum'};
  if ( defined($custnum) && $custnum =~ /^\d+$/ ) {
    # probably the most efficient way to check ticket ownership
    my $Link = RT::Link->new($session->{CurrentUser});
    $Link->LoadByCols( LocalBase => $opt{'ticket_id'},
                       Type      => 'MemberOf',
                       Target    => "freeside://freeside/cust_main/$custnum",
                     );
    return if ( !$Link->id );
  }
  return $Ticket;
}


=item correspond_ticket SESSION_HASHREF, OPTION => VALUE ...

Class method. Correspond on a ticket. If there is an error, returns the scalar
error. Otherwise, returns the transaction id, error message, and
RT::Transaction object.

Accepts the following options:

=over 4

=item ticket_id 

The ticket id

=item content

Correspondence content

=back

=cut

sub correspond_ticket {
  my($self, $session, %param) = @_;

  $session = $self->session($session);

  my $Ticket = RT::Ticket->new($session->{'CurrentUser'});
  my $ticketid = $Ticket->Load( $param{'ticket_id'} );
  return 'Could not load ticket' unless $ticketid;
  return 'No content' unless $param{'content'};

  $Ticket->Correspond( Content => $param{'content'} );
}

=item queues SESSION_HASHREF [, ACL ]

Retrieve a list of queues.  Pass the name of an RT access control right, 
such as 'CreateTicket', to return only queues on which the current user 
has that right.  Otherwise this will return all queues with the 'SeeQueue' 
right.

=cut

sub queues {
  my( $self, $session, $acl ) = @_;
  $session = $self->session($session);

  my $showall = $acl ? 0 : 1;
  my @result = ();
  my $q = new RT::Queues($session->{'CurrentUser'});
  $q->UnLimit;
  while (my $queue = $q->Next) {
    if ($showall || $queue->CurrentUserHasRight($acl)) {
      push @result, {
        Id          => $queue->Id,
        Name        => $queue->Name,
        Description => $queue->Description,
      };
    }
  }
  return map { $_->{Id} => $_->{Name} } @result;
}

#shameless false laziness w/RT::Interface::Web::AttemptExternalAuth
# to get logged into RT from afar
sub _web_external_auth {
  my( $self, $session ) = @_;

  my $user = $FS::CurrentUser::CurrentUser->username;

  eval 'use RT::CurrentUser;';
  die $@ if $@;

  $session ||= {};
  $session->{'CurrentUser'} = RT::CurrentUser->new();

  warn "$me _web_external_auth loading RT user for $user\n"
    if $DEBUG > 1;

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

  $session;

}

=item selfservice_priority

Returns the configured self-service priority field.

=cut

my $selfservice_priority;

sub selfservice_priority {
  return $selfservice_priority ||= do {
    my $conf = FS::Conf->new;
    $conf->config('ticket_system-selfservice_priority_field') || '';
  }
}

1;

