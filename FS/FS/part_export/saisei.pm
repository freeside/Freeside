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

This is a customer integration with Saisei.  This will set up a rate plan and tie
the rate plan to a host and the access point via the Saisei API when the broadband service is provisioned.
It will also untie the host from the rate plan, setting it to the default rate plan via the API upon unprovisioning of the broadband service.

This will create and modify the rate plans at Saisei as soon as the broadband service attached to this export is created or modified.
This will also create and modify an access point at Saisei as soon as the tower is created or modified.

To use this export, follow the below instructions:

Create a new service definition and set the table to svc_broadband.  The service name will become the Saisei rate plan name.
Set the upload and download speed for the service. This is required to be able to export the service to Saisei.
Attach this Saisei export to this service.

Create a tower and add a sector to that tower.  The sector name will be the name of the access point,
Make sure you have set the up and down rate limit for the tower and the sector.  This is required to be able to export the access point.
The tower and sector will be set up as access points at Saisei upon the creation of the tower or sector.  They will be modified at Saisei when modified in freeside.
Each sector will be attached to its tower access point using the Saisei uplink field.

Create a package for the above created service, and order this package for a customer.

Provision the service, making sure to enter the IP address associated with this service and select the tower and sector for it's access point.
This provisioned service will then be exported as a host to Saisei.

Unprovisioning this service will set the host entry at Saisei to the default rate plan with the user and access point set to <none>.

After this export is set up and attached to a service, you can export the already provisioned services by clicking the link Export provisioned services attached to this export.
Clicking on this link will export all services attached to this export not currently exported to Saisei.

This module also provides generic methods for working through the L</Saisei API>.

=cut

tie my %scripts, 'Tie::IxHash',
  'export_provisioned_services'  => { component => '/elements/popup_link.html',
                                      label     => 'Export provisioned services',
                                      description => 'will export provisioned services of part service with Saisei export attached.',
                                      html_label => '<b>Export provisioned services attached to this export.</b>',
                                    },
;

tie my %options, 'Tie::IxHash',
  'port'             => { label => 'Port',
                          default => 5000 },
  'username'         => { label => 'Saisei API User Name',
                          default => '' },
  'password'         => { label => 'Saisei API Password',
                          default => '' },
  'debug'            => { type => 'checkbox',
                          label => 'Enable debug warnings' },
;

%info = (
  'svc'             => 'svc_broadband',
  'desc'            => 'Export broadband service/account to Saisei',
  'options'         => \%options,
  'scripts'         => \%scripts,
  'notes'           => <<'END',
This is a customer integration with Saisei.  This will set up a rate plan and tie
the rate plan to a host and the access point via the Saisei API when the broadband service is provisioned.
It will also untie the host from the rate plan, setting it to the default rate plan via the API upon unprovisioning of the broadband service.
<P>
This will create and modify the rate plans at Saisei as soon as the broadband service attached to this export is created or modified.
This will also create and modify an access point at Saisei as soon as the tower is created or modified.
<P>
To use this export, follow the below instructions:
<P>
<OL>
<LI>
Create a new service definition and set the table to svc_broadband.  The service name will become the Saisei rate plan name.
Set the upload and download speed for the service. This is required to be able to export the service to Saisei.
Attach this Saisei export to this service.
</LI>
<P>
<LI>
Create a tower and add a sector to that tower.  The sector name will be the name of the access point,
Make sure you have set the up and down rate limit for the tower and the sector.  This is required to be able to export the access point.
The tower and sector will be set up as access points at Saisei upon the creation of the tower or sector.  They will be modified at Saisei when modified in freeside.
Each sector will be attached to its tower access point using the Saisei uplink field.
</LI>
<P>
<LI>
Create a package for the above created service, and order this package for a customer.
</LI>
<P>
<LI>
Provision the service, making sure to enter the IP address associated with this service and select the tower and sector for it's access point.
This provisioned service will then be exported as a host to Saisei.
<P>
Unprovisioning this service will set the host entry at Saisei to the default rate plan with the user and access point set to <i>none</i>.
</LI>
<P>
<LI>
After this export is set up and attached to a service, you can export the already provisioned services by clicking the link <b>Export provisioned services attached to this export</b>.
Clicking on this link will export all services attached to this export not currently exported to Saisei.
</LI>
</OL>
<P>

END
);

sub _export_insert {
  my ($self, $svc_broadband) = @_;

  my $rateplan_name = $self->get_rateplan_name($svc_broadband);

  # check for existing rate plan
  my $existing_rateplan;
  $existing_rateplan = $self->api_get_rateplan($rateplan_name) unless $self->{'__saisei_error'};

  # if no existing rate plan create one and modify it.
  $self->api_create_rateplan($svc_broadband, $rateplan_name) unless $existing_rateplan;
  $self->api_modify_rateplan($svc_broadband, $rateplan_name) unless ($self->{'__saisei_error'} || $existing_rateplan);
  return $self->api_error if $self->{'__saisei_error'};

  # set rateplan to existing one or newly created one.
  my $rateplan = $existing_rateplan ? $existing_rateplan : $self->api_get_rateplan($rateplan_name);

  my $username = $svc_broadband->{Hash}->{svcnum};
  my $description = $svc_broadband->{Hash}->{description};

  if (!$username) {
    $self->{'__saisei_error'} = 'no username - can not export';
    return $self->api_error;
  }
  else {
    # check for existing user.
    my $existing_user;
    $existing_user = $self->api_get_user($username) unless $self->{'__saisei_error'};
 
    # if no existing user create one.
    $self->api_create_user($username, $description) unless $existing_user;
    return $self->api_error if $self->{'__saisei_error'};

    # set user to existing one or newly created one.
    my $user = $existing_user ? $existing_user : $self->api_get_user($username);

    ## add access point
    my $tower_sector = FS::Record::qsearchs({
      'table'     => 'tower_sector',
      'select'    => 'tower.towername,
                      tower.up_rate_limit as tower_upratelimit,
                      tower.down_rate_limit as tower_downratelimit,
                      tower_sector.sectorname,
                      tower_sector.up_rate_limit as sector_upratelimit,
                      tower_sector.down_rate_limit as sector_downratelimit ',
      'addl_from' => 'LEFT JOIN tower USING ( towernum )',
      'hashref'   => {
                        'sectornum' => $svc_broadband->{Hash}->{sectornum},
                     },
    });

    my $tower_name = $tower_sector->{Hash}->{towername};
    $tower_name =~ s/\s/_/g;

    my $tower_opt = {
      'tower_name'           => $tower_name,
      'tower_uprate_limit'   => $tower_sector->{Hash}->{tower_upratelimit},
      'tower_downrate_limit' => $tower_sector->{Hash}->{tower_downratelimit},
    };

    my $tower_ap = process_tower($self, $tower_opt);
    return $self->api_error if $self->{'__saisei_error'};

    my $sector_name = $tower_sector->{Hash}->{sectorname};
    $sector_name =~ s/\s/_/g;

    my $sector_opt = {
      'tower_name'            => $tower_name,
      'sector_name'           => $sector_name,
      'sector_uprate_limit'   => $tower_sector->{Hash}->{sector_upratelimit},
      'sector_downrate_limit' => $tower_sector->{Hash}->{sector_downratelimit},
    };
    my $accesspoint = process_sector($self, $sector_opt);
    return $self->api_error if $self->{'__saisei_error'};

## get custnum and pkgpart from cust_pkg for virtual access point
    my $cust_pkg = FS::Record::qsearchs({
      'table'     => 'cust_pkg',
      'hashref'   => { 'pkgnum' => $svc_broadband->{Hash}->{pkgnum}, },
    });
    my $virtual_ap_name = $cust_pkg->{Hash}->{custnum}.'_'.$cust_pkg->{Hash}->{pkgpart}.'_'.$svc_broadband->{Hash}->{speed_down}.'_'.$svc_broadband->{Hash}->{speed_up};

    my $virtual_ap_opt = {
      'virtual_name'           => $virtual_ap_name,
      'sector_name'            => $sector_name,
      'virtual_uprate_limit'   => $svc_broadband->{Hash}->{speed_up},
      'virtual_downrate_limit' => $svc_broadband->{Hash}->{speed_down},
    };
    my $virtual_ap = process_virtual_ap($self, $virtual_ap_opt);
    return $self->api_error if $self->{'__saisei_error'};

    ## tie host to user add sector name as access point.
    $self->api_add_host_to_user(
      $user->{collection}->[0]->{name},
      $rateplan->{collection}->[0]->{name},
      $svc_broadband->{Hash}->{ip_addr},
      $virtual_ap->{collection}->[0]->{name},
    ) unless $self->{'__saisei_error'};
  }

  return $self->api_error;

}

sub _export_replace {
  my ($self, $svc_broadband) = @_;
  my $error = $self->_export_insert($svc_broadband);
  return $error;
}

sub _export_delete {
  my ($self, $svc_broadband) = @_;

  my $rateplan_name = $self->get_rateplan_name($svc_broadband);

  my $username = $svc_broadband->{Hash}->{svcnum};

  ## untie host to user
  $self->api_delete_host_to_user($username, $rateplan_name, $svc_broadband->{Hash}->{ip_addr}) unless $self->{'__saisei_error'};

  return '';
}

sub _export_suspend {
  my ($self, $svc_broadband) = @_;
  return '';
}

sub _export_unsuspend {
  my ($self, $svc_broadband) = @_;
  return '';
}

sub export_partsvc {
  my ($self, $svc_part) = @_;

  my $fcc_477_speeds;
  if ($svc_part->{Hash}->{svc_broadband__speed_down} eq "down" || $svc_part->{Hash}->{svc_broadband__speed_up} eq "up") {
    for my $type (qw( down up )) {
      my $speed_type = "broadband_".$type."stream";
      foreach my $pkg_svc (FS::Record::qsearch({
        'table'     => 'pkg_svc',
        'select'    => 'pkg_svc.*, part_pkg_fcc_option.fccoptionname, part_pkg_fcc_option.optionvalue',
        'addl_from' => ' LEFT JOIN part_pkg_fcc_option USING (pkgpart) ',
        'extra_sql' => " WHERE pkg_svc.svcpart = ".$svc_part->{Hash}->{svcpart}." AND pkg_svc.quantity > 0 AND part_pkg_fcc_option.fccoptionname = '".$speed_type."'",
      })) { $fcc_477_speeds->{
        $pkg_svc->{Hash}->{pkgpart}}->{$speed_type} = $pkg_svc->{Hash}->{optionvalue} * 1000 unless !$pkg_svc->{Hash}->{optionvalue}; }
    }
  }
  else {
    $fcc_477_speeds->{1}->{broadband_downstream} = $svc_part->{Hash}->{"svc_broadband__speed_down"};
    $fcc_477_speeds->{1}->{broadband_upstream} = $svc_part->{Hash}->{"svc_broadband__speed_up"};
  }

  foreach my $key (keys %$fcc_477_speeds) {

    $svc_part->{Hash}->{speed_down} = $fcc_477_speeds->{$key}->{broadband_downstream};
    $svc_part->{Hash}->{speed_up} = $fcc_477_speeds->{$key}->{broadband_upstream};
    $svc_part->{Hash}->{svc_broadband__speed_down} = $fcc_477_speeds->{$key}->{broadband_downstream};
    $svc_part->{Hash}->{svc_broadband__speed_up} = $fcc_477_speeds->{$key}->{broadband_upstream};

    my $temp_svc = $svc_part->{Hash};
    my $svc_broadband = {};
    map { if ($_ =~ /^svc_broadband__(.*)$/) { $svc_broadband->{Hash}->{$1} = $temp_svc->{$_}; }  } keys %$temp_svc;

    my $rateplan_name = $self->get_rateplan_name($svc_broadband, $svc_part->{Hash}->{svc});

    # check for existing rate plan
    my $existing_rateplan;
    $existing_rateplan = $self->api_get_rateplan($rateplan_name) unless $self->{'__saisei_error'};

    # Modify the existing rate plan with new service data.
    $self->api_modify_existing_rateplan($svc_broadband, $rateplan_name) unless ($self->{'__saisei_error'} || !$existing_rateplan);

    # if no existing rate plan create one and modify it.
    $self->api_create_rateplan($svc_broadband, $rateplan_name) unless $existing_rateplan;
    $self->api_modify_rateplan($svc_part, $rateplan_name) unless ($self->{'__saisei_error'} || $existing_rateplan);

  }

  return $self->api_error;

}

sub export_tower_sector {
  my ($self, $tower) = @_;

  #modify tower or create it.
  my $tower_name = $tower->{Hash}->{towername};
  $tower_name =~ s/\s/_/g;
  my $tower_opt = {
    'tower_name'           => $tower_name,
    'tower_uprate_limit'   => $tower->{Hash}->{up_rate_limit},
    'tower_downrate_limit' => $tower->{Hash}->{down_rate_limit},
    'modify_existing'      => '1', # modify an existing access point with this info
  };

  my $tower_access_point = process_tower($self, $tower_opt);

  #get list of all access points
  my $hash_opt = {
      'table'     => 'tower_sector',
      'select'    => '*',
      'hashref'   => { 'towernum' => $tower->{Hash}->{towernum}, },
  };

  #for each one modify or create it.
  foreach my $tower_sector ( FS::Record::qsearch($hash_opt) ) {
    my $sector_name = $tower_sector->{Hash}->{sectorname};
    $sector_name =~ s/\s/_/g;
    my $sector_opt = {
      'tower_name'            => $tower_name,
      'sector_name'           => $sector_name,
      'sector_uprate_limit'   => $tower_sector->{Hash}->{up_rate_limit},
      'sector_downrate_limit' => $tower_sector->{Hash}->{down_rate_limit},
      'modify_existing'       => '1', # modify an existing access point with this info
    };
    my $sector_access_point = process_sector($self, $sector_opt);
  }

  return $self->api_error;
}

## creates the rateplan name
sub get_rateplan_name {
  my ($self, $svc_broadband, $svc_name) = @_;

  my $service_part = FS::Record::qsearchs( 'part_svc', { 'svcpart' => $svc_broadband->{Hash}->{svcpart} } ) unless $svc_name;
  my $service_name = $svc_name ? $svc_name : $service_part->{Hash}->{svc};

  my $rateplan_name = $service_name . " " . $svc_broadband->{Hash}->{speed_down} . "-" . $svc_broadband->{Hash}->{speed_up};
  $rateplan_name =~ s/\s/_/g;

  return $rateplan_name;
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
    $self->{'__saisei_error'} = "Bad response from server during $method: " . $client->responseContent()
    unless ($method eq "GET");
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

  return $get_policies->{collection};
}

=head2 api_get_rateplan

Gets rateplan info for specific rateplan.

=cut

sub api_get_rateplan {
  my $self = shift;
  my $rateplan = shift;

  my $get_rateplan = $self->api_call("GET", "/rate_plans/$rateplan");
  return if $self->api_error;

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

  return $get_accesspoint;
}

=head2 api_get_host

Gets user info for specific host.

=cut

sub api_get_host {
  my $self = shift;
  my $ip = shift;

  my $get_host = $self->api_call("GET", "/hosts/$ip");

  return if $self->api_error;

  return $get_host;
}

=head2 api_create_rateplan

Creates a rateplan.

=cut

sub api_create_rateplan {
  my ($self, $svc, $rateplan) = @_;

  $self->{'__saisei_error'} = "No downrate listed for service $rateplan" if !$svc->{Hash}->{speed_down};
  $self->{'__saisei_error'} = "No uprate listed for service $rateplan" if !$svc->{Hash}->{speed_up};

  my $new_rateplan = $self->api_call(
      "PUT", 
      "/rate_plans/$rateplan",
      {
        'downstream_rate' => $svc->{Hash}->{speed_down},
        'upstream_rate' => $svc->{Hash}->{speed_up},
      },
  ) unless $self->{'__saisei_error'};

  $self->{'__saisei_error'} = "Rate Plan not created"
    unless ($new_rateplan || $self->{'__saisei_error'});

  return $new_rateplan;

}

=head2 api_modify_rateplan

Modify a new rateplan.

=cut

sub api_modify_rateplan {
  my ($self,$svc,$rateplan_name) = @_;

  # get policy list
  my $policies = $self->api_get_policies();

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

    $self->{'__saisei_error'} = "Rate Plan not modified after create"
      unless ($modified_rateplan || $self->{'__saisei_error'}); # should never happen
    
  }

  return;
 
}

=head2 api_modify_existing_rateplan

Modify a existing rateplan.

=cut

sub api_modify_existing_rateplan {
  my ($self,$svc,$rateplan_name) = @_;

  my $modified_rateplan = $self->api_call(
    "PUT",
    "/rate_plans/$rateplan_name",
    {
      'downstream_rate' => $svc->{Hash}->{speed_down},
      'upstream_rate' => $svc->{Hash}->{speed_up},
    },
  );

    $self->{'__saisei_error'} = "Rate Plan not modified"
      unless ($modified_rateplan || $self->{'__saisei_error'}); # should never happen

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
    unless ($new_user || $self->{'__saisei_error'}); # should never happen

  return $new_user;

}

=head2 api_create_accesspoint

Creates a access point.

=cut

sub api_create_accesspoint {
  my ($self,$accesspoint, $upratelimit, $downratelimit) = @_;

  # this has not been tested, but should work, if needed.
  my $new_accesspoint = $self->api_call(
      "PUT",
      "/access_points/$accesspoint",
      {
         'downstream_rate_limit' => $downratelimit,
         'upstream_rate_limit' => $upratelimit,
      },
  );

  $self->{'__saisei_error'} = "Access point not created"
    unless ($new_accesspoint || $self->{'__saisei_error'}); # should never happen
  return;

}

=head2 api_modify_accesspoint

Modify a new access point.

=cut

sub api_modify_accesspoint {
  my ($self, $accesspoint, $uplink) = @_;

  my $modified_accesspoint = $self->api_call(
    "PUT",
    "/access_points/$accesspoint",
    {
      'uplink' => $uplink, # name of attached access point
    },
  );

  $self->{'__saisei_error'} = "Rate Plan not modified"
    unless ($modified_accesspoint || $self->{'__saisei_error'}); # should never happen

  return;

}

=head2 api_modify_existing_accesspoint

Modify a existing accesspoint.

=cut

sub api_modify_existing_accesspoint {
  my ($self, $accesspoint, $uplink, $upratelimit, $downratelimit) = @_;

  my $modified_accesspoint = $self->api_call(
    "PUT",
    "/access_points/$accesspoint",
    {
      'downstream_rate_limit' => $downratelimit,
      'upstream_rate_limit' => $upratelimit,
#      'uplink' => $uplink, # name of attached access point
    },
  );

    $self->{'__saisei_error'} = "Access point not modified"
      unless ($modified_accesspoint || $self->{'__saisei_error'}); # should never happen

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
    unless ($new_host || $self->{'__saisei_error'}); # should never happen

  return $new_host;

}

=head2 api_delete_host_to_user

unties host from user and rateplan.
this will set the host entry at Saisei to the default rate plan with the user and access point set to <none>.

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
    unless ($delete_host || $self->{'__saisei_error'}); # should never happen

  return $delete_host;

}

sub process_tower {
  my ($self, $opt) = @_;

  my $existing_tower_ap;
  my $tower_name = $opt->{tower_name};

  #check if tower has been set up as an access point.
  $existing_tower_ap = $self->api_get_accesspoint($tower_name) unless $self->{'__saisei_error'};

  # modify the existing accesspoint if changing tower .
  $self->api_modify_existing_accesspoint (
    $tower_name,
    '', # tower does not have a uplink on sectors.
    $opt->{tower_uprate_limit},
    $opt->{tower_downrate_limit},
  ) if $existing_tower_ap && $opt->{modify_existing};

  #if tower does not exist as an access point create it.
  $self->api_create_accesspoint(
      $tower_name,
      $opt->{tower_uprate_limit},
      $opt->{tower_downrate_limit}
  ) unless $existing_tower_ap;

  my $accesspoint = $self->api_get_accesspoint($tower_name);

  return $accesspoint;
}

sub process_sector {
  my ($self, $opt) = @_;

  my $existing_sector_ap;
  my $sector_name = $opt->{sector_name};

  #check if sector has been set up as an access point.
  $existing_sector_ap = $self->api_get_accesspoint($sector_name);

  # modify the existing accesspoint if changing sector .
  $self->api_modify_existing_accesspoint (
    $sector_name,
    $opt->{tower_name},
    $opt->{sector_uprate_limit},
    $opt->{sector_downrate_limit},
  ) if $existing_sector_ap && $opt->{modify_existing};

  #if sector does not exist as an access point create it.
  $self->api_create_accesspoint(
    $sector_name,
    $opt->{sector_uprate_limit},
    $opt->{sector_downrate_limit},
  ) unless $existing_sector_ap;

  # Attach newly created sector to it's tower.
  $self->api_modify_accesspoint($sector_name, $opt->{tower_name}) unless ($self->{'__saisei_error'} || $existing_sector_ap);

  # set access point to existing one or newly created one.
  my $accesspoint = $existing_sector_ap ? $existing_sector_ap : $self->api_get_accesspoint($sector_name);

  return $accesspoint;
}

sub process_virtual_ap {
  my ($self, $opt) = @_;

  my $existing_virtual_ap;
  my $virtual_name = $opt->{virtual_name};

  #check if sector has been set up as an access point.
  $existing_virtual_ap = $self->api_get_accesspoint($virtual_name);

  # modify the existing virtual accesspoint if changing it. this should never happen
  $self->api_modify_existing_accesspoint (
    $virtual_name,
    $opt->{sector_name},
    $opt->{virtual_uprate_limit},
    $opt->{virtual_downrate_limit},
  ) if $existing_virtual_ap && $opt->{modify_existing};

  #if virtual ap does not exist as an access point create it.
  $self->api_create_accesspoint(
    $virtual_name,
    $opt->{virtual_uprate_limit},
    $opt->{virtual_downrate_limit},
  ) unless $existing_virtual_ap;

my $update_sector;
if ($existing_virtual_ap && ($existing_virtual_ap->{collection}->[0]->{uplink}->{link}->{name} ne $opt->{sector_name})) {
  $update_sector = 1;
}

  # Attach newly created virtual ap to tower sector ap or if sector has changed.
  $self->api_modify_accesspoint($virtual_name, $opt->{sector_name}) unless ($self->{'__saisei_error'} || ($existing_virtual_ap && !$update_sector));

  # set access point to existing one or newly created one.
  my $accesspoint = $existing_virtual_ap ? $existing_virtual_ap : $self->api_get_accesspoint($virtual_name);

  return $accesspoint;
}

sub export_provisioned_services {
  my $job = shift;
  my $param = shift;

  my $part_export = FS::Record::qsearchs('part_export', { 'exportnum' => $param->{export_provisioned_services_exportnum}, } )
  or die "unknown exportnum $param->{export_provisioned_services_exportnum}";
  bless $part_export;

  my @svcparts = FS::Record::qsearch({
    'table' => 'export_svc',
    'addl_from' => 'LEFT JOIN part_svc USING ( svcpart  ) ',
    'hashref'   => { 'exportnum' => $param->{export_provisioned_services_exportnum}, },
  });
  my $part_count = scalar @svcparts;

  my $parts = join "', '", map { $_->{Hash}->{svcpart} } @svcparts;

  my @svcs = FS::Record::qsearch({
    'table' => 'cust_svc',
    'addl_from' => 'LEFT JOIN svc_broadband USING ( svcnum  ) ',
    'extra_sql' => " WHERE svcpart in ('".$parts."')",
  }) unless !$parts;

  my $svc_count = scalar @svcs;

  my %status = {};
  for (my $c=1; $c <=100; $c=$c+1) { $status{int($svc_count * ($c/100))} = $c; }

  my $process_count=0;
  foreach my $svc (@svcs) {
    if ($status{$process_count}) { my $s = $status{$process_count}; $job->update_statustext($s); }
    ## check if service exists as host if not export it.
    _export_insert($part_export,$svc) unless api_get_host($part_export, $svc->{Hash}->{ip_addr});
    $process_count++;
  }

  return;

}

=head1 SEE ALSO

L<FS::part_export>

=cut

1;