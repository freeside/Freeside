package FS::part_export::saisei;

use strict;
use vars qw( @ISA %info );
use base qw( FS::part_export );
use Date::Format 'time2str';
use Cpanel::JSON::XS;
use MIME::Base64;
use REST::Client;
use Data::Dumper;
use FS::Conf;

=pod

=head1 NAME

FS::part_export::saisei

=head1 SYNOPSIS

Saisei integration for Freeside

=head1 DESCRIPTION

This export offers basic svc_broadband provisioning for Saisei.

This is a customer integration with Saisei.  This will setup a rate plan and tie 
the rate plan to a host and access point via the Saisei API when the broadband service is provisioned.  
It will also untie the rate plan via the API upon unprovisioning of the broadband service.

Add a new export and fill out required fields:
<UL>
<LI>Hostname or IP - <I>Host name to Saisei API</I></LI>
<LI>Port - <I>Port number to Saisei API</I></LI>
<LI>User Name -  <I>Saisei API user name</I></LI>
<LI>Password - <I>Saisei API password</I></LI>
</UL>
Create a broadband service.  The broadband service name will become the Saisei rate plan name.
Set the upload and download speed, and set the modifier to fixed.
Set IP Address to required.
Attach Saisei export to service

Create a tower and add a sector to that tower.  The sector name will be the name of the access point,
Make sure you have set an up and down rate for the Tower and Sector.

When you provision the service, enter the ip address associated to this service.
Select the Tower and Sector for it's access point.

When the service is provisioned it will auto setup the rate plan.

This module also provides generic methods for working through the L</Saisei API>.

=cut

tie my %options, 'Tie::IxHash',
  'port'             => { label => 'Port',
                          default => 5000 },
  'username'         => { label => 'User Name',
                          default => '' },
  'password'         => { label => 'Password',
                          default => '' },
  'debug'            => { type => 'checkbox',
                          label => 'Enable debug warnings' },
;

%info = (
  'svc'             => 'svc_broadband',
  'desc'            => 'Export broadband service/account to Saisei',
  'options'         => \%options,
  'notes'           => <<'END',
This is a customer integration with Saisei.  This will setup a rate plan and tie 
the rate plan to a host and access point via the Saisei API when the broadband service is provisioned.  
It will also untie the rate plan via the API upon unprovisioning of the broadband service.
<P>
Add a new export and fill out required fields:
<UL>
<LI>Hostname or IP - <I>Host name to Saisei API</I></LI>
<LI>Port - <I>Port number to Saisei API</I></LI>
<LI>User Name -  <I>Saisei API user name</I></LI>
<LI>Password - <I>Saisei API password</I></LI>
</UL>
Create a broadband service.  The broadband service name will become the Saisei rate plan name.
Set the upload and download speed, and set the modifier to fixed.
Set IP Address to required.
Attach Saisei export to service
<P>
Create a tower and add a sector to that tower.  The sector name will be the name of the access point,
Make sure you have set an up and down rate for the Tower and Sector.
<P>
When you provision the service, enter the ip address associated to this service.
Select the Tower and Sector for it's access point.
<P>
When the service is provisioned it will auto setup the rate plan.
END
);

sub _export_insert {
  my ($self, $svc_broadband) = @_;

  my $service_part = FS::Record::qsearchs( 'part_svc', { 'svcpart' => $svc_broadband->{Hash}->{svcpart} } );
  my $rateplan_name = $service_part->{Hash}->{svc};
  $rateplan_name =~ s/\s/_/g;

  # load needed info from our end
  my $cust_main = $svc_broadband->cust_main;
  return "Could not load service customer" unless $cust_main;
  my $conf = new FS::Conf;

  # get policy list
  my $policies = $self->api_get_policies();

  # check for existing rate plan
  my $existing_rateplan;
  $existing_rateplan = $self->api_get_rateplan($rateplan_name) unless $self->{'__saisei_error'};

  # if no existing rate plan create one and modify it.
  $self->api_create_rateplan($svc_broadband, $rateplan_name) unless $existing_rateplan;
  $self->api_modify_rateplan($policies->{collection}, $svc_broadband, $rateplan_name) unless ($self->{'__saisei_error'} || $existing_rateplan);

  # set rateplan to existing one or newly created one.
  my $rateplan = $existing_rateplan ? $existing_rateplan : $self->api_get_rateplan($rateplan_name);

  my $username = $svc_broadband->{Hash}->{svcnum};
  my $description = $svc_broadband->{Hash}->{description};

  if (!$username) {
    $self->{'__saisei_error'} = 'no username - can not export';
    warn "No user $username\n" if $self->option('debug');
    return $self->api_error;
  }
  else {
    # check for existing user.
    my $existing_user;
    $existing_user = $self->api_get_user($username) unless $self->{'__saisei_error'};
 
    # if no existing user create one.
    $self->api_create_user($username, $description) unless $existing_user;

    # set user to existing one or newly created one.
    my $user = $existing_user ? $existing_user : $self->api_get_user($username);

    ## add access point ?
    my $tower_sector = FS::Record::qsearchs({
      'table'     => 'tower_sector',
      'select'    => 'tower.towername,
                      tower.up_rate as toweruprate,
                      tower.down_rate as towerdownrate,
                      tower_sector.sectorname,
                      tower_sector.up_rate as sectoruprate,
                      tower_sector.down_rate as sectordownrate ',
      'addl_from' => 'LEFT JOIN tower USING ( towernum )',
      'hashref'   => {
                        'sectornum' => $svc_broadband->{Hash}->{sectornum},
                     },
    });

    my $existing_tower_ap;
    my $tower_name = $tower_sector->{Hash}->{towername};
    $tower_name =~ s/\s/_/g;

    #check if tower has been set up as an access point.
    $existing_tower_ap = $self->api_get_accesspoint($tower_name) unless $self->{'__saisei_error'};;

    #if tower does not exist as an access point create it.
    $self->api_create_accesspoint(
        $tower_name,
        $tower_sector->{Hash}->{toweruprate},
        $tower_sector->{Hash}->{towerdownrate}
    ) unless $existing_tower_ap;

    my $existing_sector_ap;
    my $sector_name = $tower_sector->{Hash}->{sectorname};
    $sector_name =~ s/\s/_/g;

    #check if sector has been set up as an access point.
    $existing_sector_ap = $self->api_get_accesspoint($sector_name);

    #if sector does not exist as an access point create it.
    $self->api_create_accesspoint(
        $sector_name,
        $tower_sector->{Hash}->{sectoruprate},
        $tower_sector->{Hash}->{sectordownrate},
        $tower_name,
    ) unless $existing_sector_ap;

    # Attach newly created sector to it's tower.
    $self->api_modify_accesspoint($sector_name, $tower_name) unless ($self->{'__saisei_error'} || $existing_sector_ap);

    # set access point to existing one or newly created one.
    my $accesspoint = $existing_sector_ap ? $existing_sector_ap : $self->api_get_accesspoint($sector_name);

    ## tie host to user add sector name as access point.
    $self->api_add_host_to_user(
      $user->{collection}->[0]->{name},
      $rateplan->{collection}->[0]->{name},
      $svc_broadband->{Hash}->{ip_addr},
      $accesspoint->{collection}->[0]->{name},
    ) unless $self->{'__saisei_error'};
  }

  return $self->api_error;

}

sub _export_replace {
  my ($self, $svc_phone) = @_;
  return '';
}

sub _export_delete {
  my ($self, $svc_broadband) = @_;

  my $cust_main = $svc_broadband->cust_main;
  return "Could not load service customer" unless $cust_main;
  my $conf = new FS::Conf;

  my $rateplan_name = $svc_broadband->{Hash}->{description};
  $rateplan_name =~ s/\s/_/g;

  my @email = map { $_->emailaddress } FS::Record::qsearch({
        'table'     => 'cust_contact',
        'select'    => 'emailaddress',
        'addl_from' => ' JOIN contact_email USING (contactnum)',
        'hashref'   => { 'custnum' => $cust_main->{Hash}->{custnum}, },
    });
  my $username = $email[0]; 

  ## tie host to user
  $self->api_delete_host_to_user($username, $rateplan_name, $svc_broadband->{Hash}->{ip_addr}) unless $self->{'__saisei_error'};

  return '';
}

sub _export_suspend {
  my ($self, $svc_phone) = @_;
  return '';
}

sub _export_unsuspend {
  my ($self, $svc_phone) = @_;
  return '';
}

=head1 Saisei API

These methods allow access to the Saisei API using the credentials
set in the export options.

=cut

=head2 api_call

Accepts I<$method>, I<$path>, I<$params> hashref and optional.
Places an api call to the specified path and method with the specified params.
Returns the decoded json object returned by the api call.
Returns empty on failure;  retrieve error messages using L</api_error>.

=cut

sub api_call {
  my ($self,$method,$path,$params) = @_;
  $self->{'__saisei_error'} = '';
  my $auth_info = $self->option('username') . ':' . $self->option('password');
  $params ||= {};

  warn "Calling $method on http://"
    .$self->{Hash}->{machine}.':'.$self->option('port')
    ."/rest/stm/configurations/running/$path\n" if $self->option('debug');

  my $data = encode_json($params) if keys %{ $params };

  my $client = REST::Client->new();
  $client->addHeader("Authorization", "Basic ".encode_base64($auth_info));
  $client->setHost('http://'.$self->{Hash}->{machine}.':'.$self->option('port'));
  $client->$method('/rest/stm/configurations/running'.$path, $data, { "Content-type" => 'application/json'});

  warn "Response Code is ".$client->responseCode()."\n" if $self->option('debug');

  my $result;

  if ($client->responseCode() eq '200' || $client->responseCode() eq '201') {
    eval { $result = decode_json($client->responseContent()) };
    unless ($result) {
      $self->{'__saisei_error'} = "Error decoding json: $@";
      return;
    }
  }
  else {
    $self->{'__saisei_error'} = "Bad response from server during $method: " . $client->responseContent();
    warn "Response Content is\n".$client->responseContent."\n" if $self->option('debug');
    return; 
  }

  return $result;
  
}

=head2 api_error

Returns the error string set by L</Saisei API> methods,
or a blank string if most recent call produced no errors.

=cut

sub api_error {
  my $self = shift;
  return $self->{'__saisei_error'} || '';
}

=head2 api_get_policies

Gets a list of global policies.

=cut

sub api_get_policies {
  my $self = shift;

  my $get_policies = $self->api_call("GET", '/policies/?token=1&order=name&start=0&limit=20&select=name%2Cpercent_rate%2Cassured%2C');
  return if $self->api_error;
  $self->{'__saisei_error'} = "Did not receive any global policies"
    unless $get_policies;

  return $get_policies;
}

=head2 api_get_rateplan

Gets rateplan info for specific rateplan.

=cut

sub api_get_rateplan {
  my $self = shift;
  my $rateplan = shift;

  my $get_rateplan = $self->api_call("GET", "/rate_plans/$rateplan");
  return if $self->api_error;
  $self->{'__saisei_error'} = "Did not receive any rateplan info"
    unless $get_rateplan;

  return $get_rateplan;
}

=head2 api_get_user

Gets user info for specific user.

=cut

sub api_get_user {
  my $self = shift;
  my $user = shift;

  my $get_user = $self->api_call("GET", "/users/$user");
  return if $self->api_error;
  $self->{'__saisei_error'} = "Did not receive any user info"
    unless $get_user;

  return $get_user;
}

=head2 api_get_accesspoint

Gets user info for specific access point.

=cut

sub api_get_accesspoint {
  my $self = shift;
  my $accesspoint = shift;

  my $get_accesspoint = $self->api_call("GET", "/access_points/$accesspoint");
  return if $self->api_error;
  $self->{'__saisei_error'} = "Did not receive any access point info"
    unless $get_accesspoint;

  return $get_accesspoint;
}

=head2 api_create_rateplan

Creates a rateplan.

=cut

sub api_create_rateplan {
  my ($self, $svc, $rateplan) = @_;

  my $new_rateplan = $self->api_call(
      "PUT", 
      "/rate_plans/$rateplan",
      {
        'downstream_rate' => $svc->{Hash}->{speed_down},
        'upstream_rate' => $svc->{Hash}->{speed_up},
      },
  );

  $self->{'__saisei_error'} = "Rate Plan not created"
    unless $new_rateplan; # should never happen
  return $new_rateplan;

}

=head2 api_modify_rateplan

Modify a rateplan.

=cut

sub api_modify_rateplan {
  my ($self,$policies,$svc,$rateplan_name) = @_;

  foreach my $policy (@$policies) {
    my $policyname = $policy->{name};
    my $rate_multiplier = '';
    if ($policy->{background}) { $rate_multiplier = ".01"; }
    my $modified_rateplan = $self->api_call(
      "PUT", 
      "/rate_plans/$rateplan_name/partitions/$policyname",
      {
        'restricted'      =>  $policy->{assured},         # policy_assured_flag
        'rate_multiplier' => $rate_multiplier,           # policy_background 0.1
        'rate'            =>  $policy->{percent_rate}, # policy_percent_rate
      },
    );

    $self->{'__saisei_error'} = "Rate Plan not modified"
      unless $modified_rateplan; # should never happen
    
  }

  return;
 
}

=head2 api_create_user

Creates a user.

=cut

sub api_create_user {
  my ($self,$user, $description) = @_;

  my $new_user = $self->api_call(
      "PUT", 
      "/users/$user",
      {
        'description' => $description,
      },
  );

  $self->{'__saisei_error'} = "User not created"
    unless $new_user; # should never happen

  return $new_user;

}

=head2 api_create_accesspoint

Creates a access point.

=cut

sub api_create_accesspoint {
  my ($self,$accesspoint, $uprate, $downrate) = @_;

  # this has not been tested, but should work, if needed.
  my $new_accesspoint = $self->api_call(
      "PUT",
      "/access_points/$accesspoint",
      {
         'downstream_rate_limit' => $downrate,
         'upstream_rate_limit' => $uprate,
      },
  );

  $self->{'__saisei_error'} = "Access point not created"
    unless $new_accesspoint; # should never happen
  return;

}

=head2 api_modify_accesspoint

Modify a access point.

=cut

sub api_modify_accesspoint {
  my ($self, $accesspoint, $uplink) = @_;

  my $modified_rateplan = $self->api_call(
    "PUT",
    "/access_points/$accesspoint",
    {
      'uplink' => $uplink, # name of attached access point
    },
  );

  $self->{'__saisei_error'} = "Rate Plan not modified"
    unless $modified_rateplan; # should never happen

  return;

}

=head2 api_add_host_to_user

ties host to user, rateplan and default access point.

=cut

sub api_add_host_to_user {
  my ($self,$user, $rateplan, $ip, $accesspoint) = @_;

  my $new_host = $self->api_call(
      "PUT", 
      "/hosts/$ip",
      {
        'user'      => $user,
        'rate_plan' => $rateplan,
        'access_point' => $accesspoint,
      },
  );

  $self->{'__saisei_error'} = "Host not created"
    unless $new_host; # should never happen

  return $new_host;

}

=head2 api_delete_host_to_user

unties host to user and rateplan.

=cut

sub api_delete_host_to_user {
  my ($self,$user, $rateplan, $ip) = @_;

  my $default_rate_plan = $self->api_call("GET", '?token=1&select=default_rate_plan');
    return if $self->api_error;
  $self->{'__saisei_error'} = "Did not receive a default rate plan"
    unless $default_rate_plan;

  my $default_rateplan_name = $default_rate_plan->{collection}->[0]->{default_rate_plan}->{link}->{name};

  my $delete_host = $self->api_call(
      "PUT",
      "/hosts/$ip",
      {
        'user'          => '<none>',
        'access_point'  => '<none>',
        'rate_plan'     => $default_rateplan_name,
      },
  );

  $self->{'__saisei_error'} = "Host not created"
    unless $delete_host; # should never happen

  return $delete_host;

}

=head1 SEE ALSO

L<FS::part_export>

=cut

1;