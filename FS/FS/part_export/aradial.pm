package FS::part_export::aradial;

use base qw( FS::part_export );
use LWP::UserAgent;
use HTTP::Request;
use Tie::IxHash;
use XML::LibXML;
use URI;
use Date::Format 'time2str';
use Data::Dumper;
use vars qw( %options %info $me $DEBUG );
use strict;

$me = '[FS::part_export::aradial]';
$DEBUG = 2;

tie %options, 'Tie::IxHash',
  'port'  => { label => 'HTTP port', default => 8000 },
  'login' => { label => 'Admin username' },
  'pass'  => { label => 'Admin password' },
  'realm' => { label => 'Admin authentication realm' },
  'group' => { label => 'Group name' },
;

%info = (
  'svc'       => 'svc_acct',
  'desc'      => 'Export accounts to Aradial RADIUS HTTP interface',
  'options'   => \%options,
  'nodomain'  => 'Y',
  'notes'     => '
<p>This export maintains user accounts on an Aradial Technologies access
control server, via the HTTP interface.  The export hostname and the 
<i>HTTP port</i> option determine the location of the server.</p>
<p><i>Admin username, password, authentication realm</i> are the settings
for the HTTP interface, set in the "Admin Web Interface Security" options
for your Aradial server.</p>
<p><i>Group name</i> is the user group to assign to new users, and must
already exist on the Aradial server.  Currently this export will assign 
all users to a single group; if you want multiple groups for different 
service types, create another export instance.</p>
'
);

sub export_insert {
  my ($self, $svc) = @_;
  my $result = $self->request_user_edit(
    'Add'   => 1,
    $self->svc_acct_params($svc),
  );
  if ($svc->cust_svc->cust_pkg->susp > 0 ) {
    $result ||= $self->export_suspend($svc);
  }
  $result;
}

sub export_replace {
  my ($self, $new, $old) = @_;
  if ($new->username ne $old->username) {
    return $old->export_delete || $new->export_insert;
  }
  my $UserLockout = 0;
  $UserLockout = 1 if $new->cust_svc->cust_pkg->susp > 0;
  $self->request_user_edit(
    'Page'    => 'UserEdit',
    'Modify'  => 1,
    $self->svc_acct_params($new),
    UserLockout => $UserLockout,
  );
}

sub export_suspend {
  my ($self, $svc) = @_;
  $self->request_user_edit(
    'Modify'  => 1,
    'UserID'  => $svc->username,
    'UserLockout' => 1,
  );
}

sub export_unsuspend {
  my ($self, $svc) = @_;
  $self->request_user_edit(
    'Modify'  => 1,
    'UserID'  => $svc->username,
    'UserLockout' => 0,
  );
}

sub export_delete {
  my ($self, $svc) = @_;
  $self->request_user_edit(
    'ConfirmDelete' => 1,
    ('$Delete$' . $svc->username) => 1,
  );
}

# Send a request to the 'UserEdit' interface, and process the response into
# an error string (empty on success, per Freeside convention).

sub request_user_edit {
  my ($self, @params) = @_;
  my $result = eval { $self->request( Page => 'UserEdit', @params ) };
  return $result unless ref($result);
  my $status = $result->findvalue('Result/Status/@value'); # XPath
  if ($status eq 'Success') {
    return '';
  } else {
    my $error = $result->findvalue('Result/Reason/@value')
                || 'unknown error';
    return "updating Aradial user database: $error";
  }
}

# Send a request to any interface, parse the response (from XML), and
# return it (as an XML::LibXML::Document).  Returns a string if there's an 
# HTTP error.

sub request {
  my $self = shift;
  my @params = @_;
  my $path = '/ArdWeb/ARDAdminIs.dll'; # I think this is always right
  my $url = URI->new('http://' . $self->host . $path);
  warn "$me request: \n".Dumper(\@params)."\n\n" if $DEBUG >= 2;
  my $response = $self->ua->post($url, \@params);
  if ( $response->is_success ) {
    my $content = $response->decoded_content;
    warn "$me response: \n$content\n\n" if $DEBUG >= 2;
    return $self->parser->parse_string($content);
    # the formats of these are _variable_.
    # Some of them have a <Result><Status value="Success"><Entity ... >
    # kind of structure, but not all.  They do all seem to be XML, though.
  } else {
    return "API request error: ".$response->status_line;
  }
}

sub svc_acct_params {
  my $self = shift;
  my $svc = shift;
  my $pkg = $svc->cust_svc->cust_pkg;
  my $cust = $pkg->cust_main;
  my $location = $pkg->cust_location;
  # should we use the package contact's name/phone here?

  my $setup_date = time2str('D%Y-%m-%d',
    ($pkg->setup || $pkg->start_date || time)
  );
  my $expire_date = $pkg->expire ? time2str('D%Y-%m-%d', $pkg->expire) : '';

  (
    'db_Users.UserID'               => $svc->username,
    $self->password_params($svc),
    'db_$N$Users.Status'            => 0, # we suspend using UserLockout
    'db_$D$Users.StartDate'         => $setup_date,
    'db_$D$Users.UserExpiryDate'    => $expire_date,
    'db_$RS$Users.GroupName'        => $self->option('group'),
    'db_$I$Users.UserIP'            => $svc->slipip,
    'db_UserDetails.FirstName'      => $cust->first,
    'db_UserDetails.LastName'       => $cust->last,
    'db_UserDetails.Company'        => $cust->company,
    'db_UserDetails.Email'          => $cust->invoicing_list_emailonly_scalar,
    'db_UserDetails.Address1'       => $location->address1,
    'db_UserDetails.Address2'       => $location->address2,
    'db_UserDetails.City'           => $location->city,
    'db_%GS%UserDetails.State'      => $location->state,
    'db_%GS%UserDetails.Country'    => $location->country,
    'db_UserDetails.Zip'            => $location->zip,
    'db_UserDetails.PhoneHome'      => ($cust->daytime || $cust->night || $cust->mobile),
    'db_UserDetails.PhoneFax'       => $cust->fax,
  );
}

sub password_params {
  my ($self, $svc) = @_;

  my $password_encryption = 0;
  my $password = $svc->_password;
  if ($svc->_password_encoding eq 'crypt') {
    if ($svc->_password_encryption eq 'des') {
      $password_encryption = 2;
    } elsif ( $svc->_password_encryption eq 'md5') {
      $password_encryption = 5;
    }
  } elsif ( $svc->_password_encoding eq 'ldap' ) {
    $svc->_password =~ /^\{([\w-]+)\}(.*)$/;
    $password = $2;
    if ($1 eq 'MD5') {
      $password_encryption = 7;
    } elsif ($1 eq 'SHA' or $1 eq 'SHA-1') {
      $password_encryption = 1;
    }
  }
  ( Password => $password,
    PasswordEncryptionType => $password_encryption
  );
}

# return the XML parser
sub parser {
  my $self = shift;
  $self->{_parser} ||= XML::LibXML->new;
}

# return hostname:port
sub host {
  my $self = shift;
  $self->machine . ':' . $self->option('port');
}

# return the LWP::UserAgent object
sub ua {
  my $self = shift;
  $self->{_ua} ||= do {
    my $ua = LWP::UserAgent->new;
    $ua->credentials(
      $self->host,
      $self->option('realm'),
      $self->option('login'),
      $self->option('pass')
    );
    $ua;
  }
}

1;
