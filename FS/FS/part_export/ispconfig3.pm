package FS::part_export::ispconfig3;

use strict;

use base qw( FS::part_export );

use Data::Dumper;
use SOAP::Lite;

=pod

=head1 NAME

FS::part_export::ispconfig3

=head1 SYNOPSIS

ISPConfig 3 integration for Freeside

=head1 DESCRIPTION

This export offers basic svc_acct provisioning for ISPConfig 3.
All email accounts will be assigned to a single specified client.

This module also provides generic methods for working through the L</ISPConfig3 API>.

=cut

use vars qw( %info );

my @yesno = (
  options => ['y','n'],
  option_labels => { 'y' => 'yes', 'n' => 'no' },
);

tie my %options, 'Tie::IxHash',
  'soap_location'      => { label   => 'SOAP Location' },
  'username'           => { label   => 'User Name',
                            default => '' },
  'password'           => { label   => 'Password',
                            default => '' },
  'debug'              => { type    => 'checkbox',
                            label   => 'Enable debug warnings' },
  'subheading'         => { type    => 'title',
                            label   => 'Account defaults' },
  'client_id'          => { label   => 'Client ID' },
  'server_id'          => { label   => 'Server ID' },
  'maildir'            => { label   => 'Maildir (substitutions from svc_acct, e.g. /mail/$domain/$username)', },
  'cc'                 => { label   => 'Cc' },
  'autoresponder_text' => { label   => 'Autoresponder text', 
                            default => 'Out of Office Reply' },
  'move_junk'          => { type    => 'select',
                            options => ['y','n'],
                            option_labels => { 'y' => 'yes', 'n' => 'no' },
                            label   => 'Move junk' },
  'postfix'            => { type    => 'select',
                            @yesno,
                            label   => 'Postfix' },
  'access'             => { type    => 'select',
                            @yesno,
                            label   => 'Access' },
  'disableimap'        => { type    => 'select',
                            @yesno,
                            label   => 'Disable IMAP' },
  'disablepop3'        => { type    => 'select',
                            @yesno,
                            label   => 'Disable POP3' },
  'disabledeliver'     => { type    => 'select',
                            @yesno,
                            label   => 'Disable deliver' },
  'disablesmtp'        => { type    => 'select',
                            @yesno,
                            label   => 'Disable SMTP' },
;

%info = (
  'svc'             => 'svc_acct',
  'desc'            => 'Export email account to ISPConfig 3',
  'options'         => \%options,
  'no_machine'      => 1,
  'notes'           => <<'END',
All email accounts will be assigned to a single specified client and server.
END
);

sub _mail_user_params {
  my ($self, $svc_acct) = @_;
  # all available api fields are in comments below, even if we don't use them
  return {
    #server_id  (int(11))
    'server_id' => $self->option('server_id'),
    #email  (varchar(255))
    'email' => $svc_acct->username.'@'.$svc_acct->domain,
    #login  (varchar(255))
    'login' => $svc_acct->username.'@'.$svc_acct->domain,
    #password  (varchar(255))
    'password' => $svc_acct->_password,
    #name  (varchar(255))
    'name' => $svc_acct->finger,
    #uid  (int(11))
    'uid' => $svc_acct->uid,
    #gid  (int(11))
    'gid' => $svc_acct->gid,
    #maildir  (varchar(255))
    'maildir' => $self->_substitute($self->option('maildir'),$svc_acct),
    #quota  (bigint(20))
    'quota' => $svc_acct->quota,
    #cc  (varchar(255))
    'cc' => $self->option('cc'),
    #homedir  (varchar(255))
    'homedir' => $svc_acct->dir,

    ## initializing with autoresponder off, but this could become an export option...
    #autoresponder  (enum('n','y'))
    'autoresponder' => 'n',
    #autoresponder_start_date  (datetime)
    #autoresponder_end_date  (datetime)
    #autoresponder_text  (mediumtext)
    'autoresponder_text' => $self->option('autoresponder_text'),

    #move_junk  (enum('n','y'))
    'move_junk' => $self->option('move_junk'),
    #postfix  (enum('n','y'))
    'postfix' => $self->option('postfix'),
    #access  (enum('n','y'))
    'access' => $self->option('access'),

    ## not needed right now, not sure what it is
	#custom_mailfilter  (mediumtext)

    #disableimap  (enum('n','y'))
    'disableimap' => $self->option('disableimap'),
    #disablepop3  (enum('n','y'))
    'disablepop3' => $self->option('disablepop3'),
    #disabledeliver  (enum('n','y'))
    'disabledeliver' => $self->option('disabledeliver'),
    #disablesmtp  (enum('n','y'))
    'disablesmtp' => $self->option('disablesmtp'),
  };
}

sub _export_insert {
  my ($self, $svc_acct) = @_;
  my $params = $self->_mail_user_params($svc_acct);
  $self->api_login;
  my $remoteid = $self->api_call('mail_user_add',$self->option('client_id'),$params);
  return $self->api_error_logout if $self->api_error;
  my $error = $self->set_remoteid($svc_acct,$remoteid);
  $error = "Remote system updated, but error setting remoteid ($remoteid): $error"
    if $error;
  $self->api_logout;
  $error ||= "Systems updated, but error logging out: ".$self->api_error
    if $self->api_error;
  return $error;
}

sub _export_replace {
  my ($self, $svc_acct, $svc_acct_old) = @_;
  my $remoteid = $self->get_remoteid($svc_acct_old);
  return "Could not load remoteid for old service" unless $remoteid;
  my $params = $self->_mail_user_params($svc_acct);
  #API docs claim "Returns the number of affected rows"
  my $success = $self->api_call('mail_user_update',$self->option('client_id'),$remoteid,$params);
  return $self->api_error_logout if $self->api_error;
  return "Server returned no rows updated, but no other error message" unless $success;
  my $error = '';
  unless ($svc_acct->svcnum eq $svc_acct_old->svcnum) { # are these ever not equal?
    $error = $self->set_remoteid($svc_acct,$remoteid);
    $error = "Remote system updated, but error setting remoteid ($remoteid): $error"
      if $error;
  }
  $self->api_logout;
  $error ||= "Systems updated, but error logging out: ".$self->api_error
    if $self->api_error;
  return $error;
}

sub _export_delete {
  my ($self, $svc_acct) = @_;
  my $remoteid = $self->get_remoteid($svc_acct);
  return "Could not load remoteid for old service" unless $remoteid;
  #API docs claim "Returns the number of deleted records"
  my $success = $self->api_call('mail_user_delete',$remoteid);
  return $self->api_error_logout if $self->api_error;
  my $error = $success ? '' : "Server returned no records deleted";
  $self->api_logout;
  $error ||= "Systems updated, but error logging out: ".$self->api_error
    if $self->api_error;
  return $error;
}

sub _export_suspend {
  my ($self, $svc_acct) = @_;
  return '';
}

sub _export_unsuspend {
  my ($self, $svc_acct) = @_;
  return '';
}

=head1 ISPConfig3 API

These methods allow access to the ISPConfig3 API using the credentials
set in the export options.

=cut

=head2 api_call

Accepts I<$method> and I<@params>.  Places an api call to the specified
method with the specified params.  Returns the result of that call
(empty on failure.)  Retrieve error messages using L</api_error>.

Do not include session id in list of params;  it will be included
automatically.  Must run L</api_login> first.

=cut

sub api_call {
  my ($self,$method,@params) = @_;
  $self->{'__ispconfig_response'} = undef;
  # This does get used by api_login,
  # to retrieve the session id after it sets the client,
  # so we only check for existence of client,
  # and we only include session id if we have one
  my $client = $self->{'__ispconfig_client'};
  unless ($client) {
    $self->{'__ispconfig_error'} = 'Not logged in';
    return;
  }
  if ($self->{'__ispconfig_session'}) {
    unshift(@params,$self->{'__ispconfig_session'});
  }
  # Contact server in eval, to trap connection errors
  warn "Calling SOAP method $method with params:\n".Dumper(\@params)."\n"
    if $self->option('debug');
  my $response = eval { $client->$method(@params) };
  unless ($response) {
    $self->{'__ispconfig_error'} = "Error contacting server: $@";
    return;
  }
  # Set results and return
  $self->{'__ispconfig_error'} = $response->fault
                               ? "Error from server: " . $response->faultstring
                               : '';
  $self->{'__ispconfig_response'} = $response;
  return $response->result;
}

=head2 api_error

Returns the error string set by L</ISPConfig3 API> methods,
or a blank string if most recent call produced no errors.

=cut

sub api_error {
  my $self = shift;
  return $self->{'__ispconfig_error'} || '';
}

=head2 api_error_logout

Attempts L</api_logout>, but returns L</api_error> message from
before logout was attempted.  Useful for logging out
properly after an error.

=cut

sub api_error_logout {
  my $self = shift;
  my $error = $self->api_error;
  $self->api_logout;
  return $error;
}

=head2 api_login

Initializes an api session using the credentials for this export.
Returns true on success, false on failure.
Retrieve error messages using L</api_error>.

=cut

sub api_login {
  my $self = shift;
  if ($self->{'__ispconfig_session'} || $self->{'__ispconfig_client'}) {
    $self->{'__ispconfig_error'} = 'Already logged in';
    return;
  }
  $self->{'__ispconfig_session'} = undef;
  $self->{'__ispconfig_client'} =
    SOAP::Lite->proxy($self->option('soap_location'), ssl_opts => [ verify_hostname => 0 ] )
    || undef;
  unless ($self->{'__ispconfig_client'}) {
    $self->{'__ispconfig_error'} = 'Error creating SOAP client';
    return;
  }
  $self->{'__ispconfig_session'} = 
    $self->api_call('login',$self->option('username'),$self->option('password'))
    || undef;
  return unless $self->{'__ispconfig_session'};
  return 1;
}

=head2 api_logout

Ends the current api session established by L</api_login>.
Returns true on success, false on failure.

=cut

sub api_logout {
  my $self = shift;
  unless ($self->{'__ispconfig_session'}) {
    $self->{'__ispconfig_error'} = 'Not logged in';
    return;
  }
  my $result = $self->api_call('logout');
  # clear these even if there was a failure to logout
  $self->{'__ispconfig_client'} = undef;
  $self->{'__ispconfig_session'} = undef;
  return if $self->api_error;
  return 1;
}

# false laziness with portaone export
sub _substitute {
  my ($self, $string, @objects) = @_;
  return '' unless $string;
  foreach my $object (@objects) {
    next unless $object;
    my @fields = $object->fields;
    push(@fields,'domain') if $object->table eq 'svc_acct';
    foreach my $field (@fields) {
      next unless $field;
      my $value = $object->$field;
      $string =~ s/\$$field/$value/g;
    }
  }
  # strip leading/trailing whitespace
  $string =~ s/^\s//g;
  $string =~ s/\s$//g;
  return $string;
}

=head1 SEE ALSO

L<FS::part_export>

=head1 AUTHOR

Jonathan Prykop 
jonathan@freeside.biz

=cut

1;


