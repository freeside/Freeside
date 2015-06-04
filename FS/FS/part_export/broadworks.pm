package FS::part_export::broadworks;

use base qw( FS::part_export );
use strict;

use Tie::IxHash;
use FS::Record qw(dbh qsearch qsearchs);
use Locale::SubCountry;

our $me = '[broadworks]';
our %client; # exportnum => client object
our %expire; # exportnum => timestamp on which to refresh the client

tie my %options, 'Tie::IxHash',
  'service_provider'=> { label => 'Service Provider ID' },
  'admin_user'      => { label => 'Administrative user ID' },
  'admin_pass'      => { label => 'Administrative password' },
  'domain'          => { label => 'Domain' },
  'user_limit'      => { label    => 'Maximum users per customer',
                         default  => 100 },
  'debug'           => { label => 'Enable debugging',
                         type  => 'checkbox',
                       },
;

# do we need roles for this?
# no. cust_main -> group, svc_phone -> pilot/single user, 
# phone_device -> access device
#
# phase 2: svc_pbx -> trunk group, pbx_extension -> trunk user

our %info = (
  'svc'      => [qw( svc_phone svc_pbx )], # part_device?
  'desc'     =>
    'Provision phone and PBX services to a Broadworks Application Server',
  'options'  => \%options,
  'notes'    => <<'END'
<P>Export to <b>BroadWorks Application Server</b>.</P>
<P>In the simple case where one IP phone corresponds to one public phone
number, this requires a svc_phone definition and a part_device. The "title"
field ("external name") of the part_device must be one of the access device
type names recognized by BroadWorks, such as "Polycom Soundpoint IP 550",
"SNOM 320", or "Generic SIP Phone".</P>
<P>
END
);

sub export_insert {
  my($self, $svc_x) = (shift, shift);

  my $cust_main = $svc_x->cust_main;
  my ($groupId, $error) = $self->set_cust_main_Group($cust_main);
  return $error if $error;

  if ( $svc_x->isa('FS::svc_phone') ) {
    my $userId;
    ($userId, $error) = $self->set_svc_phone_User($svc_x, $groupId);

    $error ||= $self->set_sip_authentication($userId, $userId, $svc_x->sip_password);

    return $error if $error;

  } elsif ( $svc_x->isa('FS::svc_pbx') ) {
    # noop
  }

  '';
}

sub export_replace {
  my($self, $svc_new, $svc_old) = @_;

  my $cust_main = $svc_new->cust_main;
  my ($groupId, $error) = $self->set_cust_main_Group($cust_main);
  return $error if $error;

  if ( $svc_new->isa('FS::svc_phone') ) {
    my $oldUserId = $self->userId($svc_old);
    my $newUserId = $self->userId($svc_new);

    if ( $oldUserId ne $newUserId ) {
      my ($success, $message) = $self->request(
        User => 'UserModifyUserIdRequest',
        userId    => $oldUserId,
        newUserId => $newUserId
      );
      return $message if !$success;
    }

    if ( $svc_old->phonenum ne $svc_new->phonenum ) {
      $error ||= $self->release_number($svc_old->phonenum, $groupId);
    }

    my $userId;
    ($userId, $error) = $self->set_svc_phone_User($svc_new, $groupId);
    $error ||= $self->set_sip_authentication($userId, $userId, $svc_new->sip_password);

    if ($error and $oldUserId ne $newUserId) {
      # rename it back, then
      my ($success, $message) = $self->request(
        User => 'UserModifyUserIdRequest',
        userId    => $newUserId,
        newUserId => $oldUserId
      );
      # if it fails, we can't really fix it
      return "$error; unable to reverse user ID change: $message" if !$success;
    }

    return $error if $error;

  } elsif ( $svc_new->isa('FS::svc_pbx') ) {
    # noop
  }

  '';
}

sub export_delete {
  my ($self, $svc_x) = @_;

  my $cust_main = $svc_x->cust_main;
  my $groupId = $self->groupId($cust_main);

  if ( $svc_x->isa('FS::svc_phone') ) {
    my $userId = $self->userId($svc_x);
    my $error = $self->delete_User($userId)
             || $self->release_number($svc_x->phonenum, $groupId);
    return $error if $error;
  } elsif ( $svc_x->isa('FS::svc_pbx') ) {
    # noop
  }

  # find whether the customer still has any services on this platform
  # (other than the one being deleted)
  my %svcparts = map { $_->svcpart => 1 } $self->export_svc;
  my $svcparts = join(',', keys %svcparts);
  my $num_svcs = FS::cust_svc->count(
    '(select custnum from cust_pkg where cust_pkg.pkgnum = cust_svc.pkgnum) '.
    ' = ? '.
    ' AND svcnum != ?'.
    " AND svcpart IN ($svcparts)",
    $cust_main->custnum,
    $svc_x->svcnum
  );

  if ( $num_svcs == 0 ) {
    warn "$me removed last service for group $groupId; deleting group.\n";
    my $error = $self->delete_Group($groupId);
    warn "$me error deleting group: $error\n" if $error;
    return "$error (removing customer group)" if $error;
  }

  '';
}

sub export_device_insert {
  my ($self, $svc_x, $device) = @_;

  if ( $device->count('svcnum = ?', $svc_x->svcnum) > 1 ) {
    return "This service already has a device.";
  }

  my $cust_main = $svc_x->cust_main;
  my $groupId = $self->groupId($cust_main);

  my ($deviceName, $error) = $self->set_device_AccessDevice($device, $groupId);
  return $error if $error;

  if ( $device->isa('FS::phone_device') ) {
    return $self->set_endpoint( $self->userId($svc_x), $deviceName);
  } # else pbx_device, extension_device

  '';
}

sub export_device_replace {
  my ($self, $svc_x, $new_device, $old_device) = @_;
  my $cust_main = $svc_x->cust_main;
  my $groupId = $self->groupId($cust_main);

  my $new_deviceName = $self->deviceName($new_device);
  my $old_deviceName = $self->deviceName($old_device);

  if ($new_deviceName ne $old_deviceName) {

    # do it in this order to switch the service endpoint over to the new 
    # device.
    return $self->export_device_insert($svc_x, $new_device)
        || $self->delete_Device($old_deviceName, $groupId);

  } else { # update in place

    my ($deviceName, $error) = $self->set_device_AccessDevice($new_device, $groupId);
    return $error if $error;

  }
}

sub export_device_delete {
  my ($self, $svc_x, $device) = @_;

  if ( $device->isa('FS::phone_device') ) {
    my $error = $self->set_endpoint( $self->userId($svc_x), '' );
    return $error if $error;
  } # else...

  return $self->delete_Device($self->deviceName($device));
}


=head2 CREATE-OR-UPDATE METHODS

These take a Freeside object that can be exported to the Broadworks system,
determine if it already has been exported, and if so, update it to match the
Freeside object. If it's not already there, they create it. They return a list
of two objects:
- that object's identifying string or hashref or whatever in Broadworks, and
- an error message, if creating the object failed.

=over 4

=item set_cust_main_Group CUST_MAIN

Takes a L<FS::cust_main>, creates a Group for the customer, and returns a 
GroupId. If the Group exists, it will be updated with the current customer
and export settings.

=cut

sub set_cust_main_Group {
  my $self = shift;
  my $cust_main = shift;
  my $location = $cust_main->ship_location;

  my $LSC = Locale::SubCountry->new($location->country)
    or return(0, "Invalid country code ".$location->country);
  my $state_name;
  if ( $LSC->has_sub_countries ) {
    $state_name = $LSC->full_name( $location->state );
  }

  my $groupId = $self->groupId($cust_main);
  my %group_info = (
    $self->SPID,
    groupId           => $groupId,
    defaultDomain     => $self->option('domain'),
    userLimit         => $self->option('user_limit'),
    groupName         => $cust_main->name_short,
    callingLineIdName => $cust_main->name_short,
    contact => {
      contactName     => $cust_main->contact_firstlast,
      contactNumber   => (   $cust_main->daytime
                          || $cust_main->night
                          || $cust_main->mobile
                          || undef
                         ),
      contactEmail    => ( ($cust_main->all_emails)[0] || undef ),
    },
    address => {
      addressLine1    => $location->address1,
      addressLine2    => ($location->address2 || undef),
      city            => $location->city,
      stateOrProvince => $state_name,
      zipOrPostalCode => $location->zip,
      country         => $location->country,
    },
  );

  my ($success, $message) = $self->request('Group' => 'GroupGetRequest14sp7',
    $self->SPID,
    groupId => $groupId
  );

  if ($success) { # update it with the curent params

    ($success, $message) =
      $self->request('Group' => 'GroupModifyRequest', %group_info);

  } elsif ($message =~ /Group not found/) {

    # create a new group
    ($success, $message) =
      $self->request('Group' => 'GroupAddRequest', %group_info);

    if ($success) {
      # tell the group that its users in general are allowed to use
      # Authentication
      ($success, $message) = $self->request(
        'Group' => 'GroupServiceModifyAuthorizationListRequest',
        $self->SPID,
        groupId => $groupId,
        userServiceAuthorization => {
          serviceName => 'Authentication',
          authorizedQuantity => { unlimited => 'true' },
        },
      );
    }

    if ($success) {
      # tell the group that each new user, specifically, is allowed to 
      # use Authentication
      ($success, $message) = $self->request(
        'Group' => 'GroupNewUserTemplateAssignUserServiceListRequest',
        $self->SPID,
        groupId => $groupId,
        serviceName => 'Authentication',
      );
    }

  } # else we somehow failed to fetch the group; throw an error

  if ($success) {
    return ($groupId, '');
  } else {
    return ('', $message);
  }
}

=item set_svc_phone_User SVC_PHONE, GROUPID

Creates a User object corresponding to this svc_phone, in the specified 
group. If the User already exists, updates the record with the current
customer name (or phone name), phone number, and access device.

=cut

sub set_svc_phone_User {
  my ($self, $svc_phone, $groupId) = @_;

  my $error;

  # make sure the phone number is available
  $error = $self->assign_number( $svc_phone->phonenum, $groupId );

  my $userId = $self->userId($svc_phone);
  my $cust_main = $svc_phone->cust_main;

  my ($first, $last);
  if ($svc_phone->phone_name =~ /,/) {
    ($last, $first) = split(/,\s*/, $svc_phone->phone_name);
  } elsif ($svc_phone->phone_name =~ / /) {
    ($first, $last) = split(/ +/, $svc_phone->phone_name, 2);
  } else {
    $first = $cust_main->first;
    $last = $cust_main->last;
  }

  my %new_user = (
    $self->SPID,
    groupId                 => $groupId,
    userId                  => $userId,
    lastName                => $last,
    firstName               => $first,
    callingLineIdLastName   => $last,
    callingLineIdFirstName  => $first,
    password                => $svc_phone->sip_password,
    # not supported: nameDialingName; Hiragana names
    phoneNumber             => $svc_phone->phonenum,
    callingLinePhoneNumber  => $svc_phone->phonenum,
  );

  # does the user exist?
  my ($success, $message) = $self->request(
    'User' => 'UserGetRequest21',
    userId => $userId
  );

  if ( $success ) { # modify in place

    ($success, $message) = $self->request(
      'User' => 'UserModifyRequest17sp4',
      %new_user
    );

  } elsif ( $message =~ /User not found/ ) { # create new

    ($success, $message) = $self->request(
      'User' => 'UserAddRequest17sp4',
      %new_user
    );

  }

  if ($success) {
    return ($userId, '');
  } else {
    return ('', $message);
  }
}

=item set_device_AccessDevice DEVICE, [ GROUPID ]

Creates/updates an Access Device Profile. This is a record for a 
I<specific physical device> that can send/receive calls. (Not to be confused
with an "Access Device Endpoint", which is a I<port> on such a device.) DEVICE
can be any record with a foreign key to L<FS::part_device>.

If GROUPID is specified, this device profile will be created at the Group
level in that group; otherwise it will be a ServiceProvider level record.

=cut

sub set_device_AccessDevice {
  my $self = shift;
  my $device = shift;
  my $groupId = shift;

  my $deviceName = $self->deviceName($device);

  my $svc_x;
  if ($device->svcnum) {
    $svc_x = FS::cust_svc->by_key($device->svcnum)->svc_x;
  } else {
    $svc_x = FS::svc_phone->new({}); # returns empty for all fields
  }

  my $part_device = $device->part_device
    or return ('', "devicepart ".$device->part_device." not defined" );

  # required fields
  my %new_device = (
    $self->SPID,
    deviceName        => $deviceName,
    deviceType        => $part_device->title,
    description       => ($svc_x->title # svc_pbx
                          || $part_device->devicename), # others
  );

  # optional fields
  $new_device{netAddress} = $svc_x->ip_addr if $svc_x->ip_addr; # svc_pbx only
  $new_device{macAddress} = $device->mac_addr if $device->mac_addr;

  my %find_device = (
    $self->SPID,
    deviceName => $deviceName
  );
  my $level = 'ServiceProvider';

  if ( $groupId ) {
    $level = 'Group';
    $find_device{groupId} = $new_device{groupId} = $groupId;
  } else {
    # shouldn't be used in our current design
    warn "$me creating access device $deviceName at Service Provider level\n";
  }

  my ($success, $message) = $self->request(
    $level, $level.'AccessDeviceGetRequest18sp1',
    %find_device
  );

  if ( $success ) { # modify in place

    ($success, $message) = $self->request(
      $level => $level.'AccessDeviceModifyRequest14',
      %new_device
    );

  } elsif ( $message =~ /Access Device not found/ ) { # create new

    ($success, $message) = $self->request(
      $level => $level.'AccessDeviceAddRequest14',
      %new_device
    );

  }

  if ($success) {
    return ($deviceName, '');
  } else {
    return ('', $message);
  }
}

=back

=head2 PROVISIONING METHODS

These return an error string on failure, and an empty string on success.

=over 4

=item assign_number NUMBER, GROUPID

Assigns a phone number to a group. If it's assigned to a different group or
doesn't belong to the service provider, this will fail. If it's already 
assigned to I<this> group, it will do nothing and return success.

=cut

sub assign_number {
  my ($self, $number, $groupId) = @_;
  # see if it's already assigned
  my ($success, $message) = $self->request(
    Group => 'GroupDnGetAssignmentListRequest18',
    $self->SPID,
    groupId           => $groupId,
    searchCriteriaDn  => {
      mode  => 'Equal To',
      value => $number,
      isCaseInsensitive => 'false',
    },
  );
  return "$message (checking phone number status)" if !$success;
  my $result = $self->oci_table( $message->{dnTable} );
  return '' if @$result > 0;

  ($success, $message) = $self->request(
    Group => 'GroupDnAssignListRequest',
    $self->SPID,
    groupId     => $groupId,
    phoneNumber => $number,
  );

  $success ? '' : $message;
}

=item release_number NUMBER, GROUPID

Unassigns a phone number from a group. If it's assigned to a user in the
group then this will fail. If it's not assigned to the group at all, this
does nothing.

=cut

sub release_number {
  my ($self, $number, $groupId) = @_;
  # see if it's already assigned
  my ($success, $message) = $self->request(
    Group => 'GroupDnGetAssignmentListRequest18',
    $self->SPID,
    groupId           => $groupId,
    searchCriteriaDn  => {
      mode  => 'Equal To',
      value => $number,
      isCaseInsensitive => 'false',
    },
  );
  return "$message (checking phone number status)" if !$success;
  my $result = $self->oci_table( $message->{dnTable} );
  return '' if @$result == 0;

  ($success, $message) = $self->request(
    Group => 'GroupDnUnassignListRequest',
    $self->SPID,
    groupId     => $groupId,
    phoneNumber => $number,
  );

  $success ? '' : $message;
}

=item set_endpoint USERID [, DEVICENAME ]

Sets the endpoint for communicating with USERID to DEVICENAME. For now, this
assumes that all devices are defined at Group level.

If DEVICENAME is null, the user will be set to have no endpoint.

=cut
      
# we only support linePort = userId, and no numbered ports

sub set_endpoint {
  my ($self, $userId, $deviceName) = @_;

  my $endpoint;
  if ( length($deviceName) > 0 ) {
    $endpoint = {
      accessDeviceEndpoint => {
        linePort      => $userId,
        accessDevice  => {
          deviceLevel => 'Group',
          deviceName  => $deviceName,
        },
      }
    };
  } else {
    $endpoint = undef;
  }
  my ($success, $message) = $self->request(
    User => 'UserModifyRequest17sp4',
    userId    => $userId,
    endpoint  => $endpoint,
  );

  $success ? '' : $message;
}

=item set_sip_authentication USERID, NAME, PASSWORD

Sets the SIP authentication credentials for USERID to (NAME, PASSWORD).

=cut

sub set_sip_authentication {
  my ($self, $userId, $userName, $password) = @_;

  my ($success, $message) = $self->request(
    'Services/ServiceAuthentication' => 'UserAuthenticationModifyRequest',
    userId      => $userId,
    userName    => $userName,
    newPassword => $password,
  );

  $success ? '' : $message;
}

=item delete_group GROUPID

Deletes the group GROUPID.

=cut

sub delete_Group {
  my ($self, $groupId) = @_;

  my ($success, $message) = $self->request(
    Group => 'GroupDeleteRequest',
    $self->SPID,
    groupId => $groupId
  );
  if ( $success or $message =~ /Group not found/ ) {
    return '';
  } else {
    return $message;
  }
}

=item delete_User USERID

Deletes the user USERID, and releases its phone number if it has one.

=cut

sub delete_User {
  my ($self, $userId) = @_;

  my ($success, $message) = $self->request(
    User => 'UserDeleteRequest',
    userId => $userId
  );
  if ($success or $message =~ /User not found/) {
    return '';
  } else {
    return $message;
  }
}

=item delete_Device DEVICENAME[, GROUPID ]

Deletes the access device DEVICENAME (from group GROUPID, or from the service
provider if there is no GROUPID).

=cut

sub delete_Device {
  my ($self, $deviceName, $groupId) = @_;

  my ($success, $message);
  if ( $groupId ) {
    ($success, $message) = $self->request(
      Group => 'GroupAccessDeviceDeleteRequest',
      $self->SPID,
      groupId => $groupId,
      deviceName => $deviceName,
    );
  } else {
    ($success, $message) = $self->request(
      ServiceProvider => 'ServiceProviderAccessDeviceDeleteRequest',
      $self->SPID,
      deviceName => $deviceName,
    );
  }
  if ( $success or $message =~ /Access Device not found/ ) {
    return '';
  } else {
    return $message;
  }
}

=back

=head2 CONVENIENCE METHODS

=over 4

=item SPID

Returns 'serviceProviderId' => the service_provider option. This is commonly
needed in request parameters.

=item groupId CUST_MAIN

Returns the groupID that goes with the specified customer.

=item userId SVC_X

Returns the userId (including domain) that should go with the specified
service.

=item deviceName DEVICE

Returns the access device name that should go with the specified phone_device
or pbx_device.

=cut

sub SPID {
  my $self = shift;
  my $id = $self->option('service_provider') or die 'service provider not set';
  'serviceProviderId' => $id
}

sub groupId {
  my $self = shift;
  my $cust_main = shift;
  'cust_main#'.$cust_main->custnum;
}

sub userId {
  my $self = shift;
  my $svc = shift;
  my $userId;
  if ($svc->phonenum) {
    $userId = $svc->phonenum;
  } else { # pbx_extension needs one of these
    die "can't determine userId for non-svc_phone service";
  }
  my $domain = $self->option('domain'); # domsvc?
  $userId .= '@' . $domain if $domain;

  return $userId;
}

sub deviceName {
  my $self = shift;
  my $device = shift;
  $device->mac_addr || ($device->table . '#' . $device->devicenum);
}

=item oci_table HASHREF

Converts the base OCITable type into an arrayref of hashrefs.

=cut

sub oci_table {
  my $self = shift;
  my $oci_table = shift;
  my @colnames = $oci_table->{colHeading};
  my @data;
  foreach my $row (@{ $oci_table->{row} }) {
    my %hash;
    @hash{@colnames} = @{ $row->{col} };
    push @data, \%hash;
  }

  \@data;
}

#################
# DID SELECTION #
#################



################
# CALL DETAILS #
################

=item import_cdrs START, END

Retrieves CDRs for calls in the date range from START to END and inserts them
as a new CDR batch. On success, returns a new cdr_batch object. On failure,
returns an error message. If there are no new CDRs, returns nothing.

=cut

##############
# API ACCESS #
##############

=item request SCOPE, COMMAND, [ ARGUMENTS... ]

Wrapper for L<BroadWorks::OCI/request>. The client object will be cached.
Returns two values: a flag, true or false, indicating success of the request,
and the decoded response message as a hashref.

On failure of the request (or failure to authenticate), the response message
will be a simple scalar containing the error message.

=cut

sub request {
  my $self = shift;

  delete $client{$self->exportnum} if $expire{$self->exportnum} < time;
  my $client = $client{$self->exportnum};
  if (!$client) {
    local $@;
    eval "use BroadWorks::OCI";
    die "$me $@" if $@;

    Log::Report::dispatcher('PERL', 'default',
      mode => ($self->option('debug') ? 'DEBUG' : 'NORMAL')
    );

    $client = BroadWorks::OCI->new(
      userId    => $self->option('admin_user'),
      password  => $self->option('admin_pass'),
    );
    my ($success, $message) = $client->login;
    return ('', $message) if !$success;

    $client{$self->exportnum} = $client; # if login succeeded
    $expire{$self->exportnum} = time + 120; # hardcoded, yeah
  }
  return $client->request(@_);
}

1;
