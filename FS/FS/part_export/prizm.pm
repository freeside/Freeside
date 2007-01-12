package FS::part_export::prizm;

use vars qw(@ISA %info %options $DEBUG);
use Tie::IxHash;
use FS::Record qw(fields);
use FS::part_export;

@ISA = qw(FS::part_export);
$DEBUG = 1;

tie %options, 'Tie::IxHash',
  'url'      => { label => 'Northbound url', default=>'https://localhost:8443/prizm/nbi' },
  'user'     => { label => 'Northbound username', default=>'nbi' },
  'password' => { label => 'Password', default => '' },
;

%info = (
  'svc'      => 'svc_broadband',
  'desc'     => 'Real-time export to Northbound Interface',
  'options'  => \%options,
  'nodomain' => 'Y',
  'notes'    => 'These are notes.'
);

sub prizm_command {
  my ($self,$namespace,$method) = (shift,shift,shift);

  eval "use Net::Prizm qw(CustomerInfo PrizmElement);";
  die $@ if $@;

  my $prizm = new Net::Prizm (
    namespace => $namespace,
    url => $self->option('url'),
    user => $self->option('user'),
    password => $self->option('password'),
  );
  
  $prizm->$method(@_);
}

sub _export_insert {
  my( $self, $svc ) = ( shift, shift );

  my $cust_main = $svc->cust_svc->cust_pkg->cust_main;

  my $err_or_som = $self->prizm_command(CustomerIfService, 'getCustomers',
                                        ['import_id'],
                                        [$cust_main->custnum],
                                        ['='],
                                       );
  return $err_or_som
    unless ref($err_or_som);

  my $pre = '';
  if ( defined $cust_main->dbdef_table->column('ship_last') ) {
    $pre = $cust_main->ship_last ? 'ship_' : '';
  }
  my $name = $pre ? $cust_main->ship_name : $cust_main->name;
  my $location = join(" ", map { my $method = "$pre$_"; $cust_main->$method }
                           qw (address1 address2 city state zip)
                     );
  my $contact = join(" ", map { my $method = "$pre$_"; $cust_main->$method }
                          qw (daytime night)
                     );

  my $pcustomer;
  if ($err_or_som->result->[0]) {
    $pcustomer = $err_or_som->result->[0]->customerId;
  }else{
    my $chashref = $cust_main->hashref;
    my $customerinfo = {
      importId         => $cust_main->custnum,
      customerName     => $name,
      customerType     => 'freeside',
      address1         => $chashref->{"${pre}address1"},
      address2         => $chashref->{"${pre}address2"},
      city             => $chashref->{"${pre}city"},
      state            => $chashref->{"${pre}state"},
      zipCode          => $chashref->{"${pre}zip"},
      workPhone        => $chashref->{"${pre}daytime"},
      homePhone        => $chashref->{"${pre}night"},
      email            => @{[$cust_main->invoicing_list_emailonly]}[0],
      extraFieldNames  => [ 'country', 'freesideId',
                          ],
      extraFieldValues => [ $chashref->{"${pre}country"}, $cust_main->custnum,
                          ],
    };

    $err_or_som = $self->prizm_command('CustomerIfService', 'addCustomer',
                                       $customerinfo);
    return $err_or_som
      unless ref($err_or_som);

    $pcustomer = $err_or_som->result;
  }
  warn "multiple prizm customers found for $cust_main->custnum"
    if scalar(@$pcustomer) > 1;

  #kinda big question/expensive
  $err_or_som = $self->prizm_command('NetworkIfService', 'getPrizmElements',
                                     ['Network Default Gateway Address'],
                                     [$svc->addr_block->ip_gateway],
                                     ['='],
                   );
  return $err_or_som
    unless ref($err_or_som);

  return "No elements in network" unless exists $err_or_som->result->[0];

  my $networkid = 0;
  for (my $i = 0; $i < $err_or_som->result->[0]->attributeNames; $i++) {
    if ($err_or_som->result->[0]->attributeNames->[$i] eq "Network.ID"){
      $networkid = $err_or_som->result->[0]->attributeValues->[$i];
      last;
    }
  }

  $err_or_som = $self->prizm_command('NetworkIfService', 'addProvisionedElement',
                                      $networkid,
                                      $svc->mac_addr,
                                      $name . " " . $svc->description,
                                      $location,
                                      $contact,
                                      sprintf("%032X", $svc->authkey),
                                      $svc->cust_svc->cust_pkg->part_pkg->pkg,
                                      $svc->vlan_profile,
                                      1,
                                     );
  return $err_or_som
    unless ref($err_or_som);

  my (@names) = ('Management IP',
                 'GPS Latitude',
                 'GPS Longitude',
                 'GPS Altitude',
                 'Site Name',
                 'Site Location',
                 'Site Contact',
                 );
  my (@values) = ($svc->ip_addr,
                  $svc->latitude,
                  $svc->longitude,
                  $svc->altitude,
                  $name,
                  $location,
                  $contact,
                  );
  $element = $err_or_som->result->elementId;
  $err_or_som = $self->prizm_command('NetworkIfService', 'setElementConfig',
                                     [ $element ],
                                     \@names,
                                     \@values,
                                     0,
                                     1,
                                    );
  return $err_or_som
    unless ref($err_or_som);

  $err_or_som = $self->prizm_command('NetworkIfService', 'setElementConfigSet',
                                     [ $element ],
                                     $svc->vlan_profile,
                                     0,
                                     1,
                                    );
  return $err_or_som
    unless ref($err_or_som);

  $err_or_som = $self->prizm_command('NetworkIfService', 'setElementConfigSet',
                                     [ $element ],
                                     $svc->cust_svc->cust_pkg->part_pkg->pkg,
                                     0,
                                     1,
                                    );
  return $err_or_som
    unless ref($err_or_som);

  $err_or_som = $self->prizm_command('NetworkIfService',
                                     'activateNetworkElements',
                                     [ $element ],
                                     1,
                                     1,
                                    );

  return $err_or_som
    unless ref($err_or_som);

  $err_or_som = $self->prizm_command('CustomerIfService',
                                     'addElementToCustomer',
                                     0,
                                     $cust_main->custnum,
                                     0,
                                     $svc->mac_addr,
                                    );

  return $err_or_som
    unless ref($err_or_som);

  '';
}

sub _export_delete {
  my( $self, $svc ) = ( shift, shift );

  my $custnum = $svc->cust_svc->cust_pkg->cust_main->custnum;

  my $err_or_som = $self->prizm_command('NetworkIfService', 'getPrizmElements',
                                        ['MAC Address'],
                                        [$svc->mac_addr],
                                        ['='],
                                       );
  return $err_or_som
    unless ref($err_or_som);

  return "Can't find prizm element for " . $svc->mac_addr
    unless $err_or_som->result->[0];

  $err_or_som = $self->prizm_command('NetworkIfService',
                                     'suspendNetworkElements',
                                     [$err_or_som->result->[0]->elementId],
                                     1,
                                     1,
                                    );

  return $err_or_som
    unless ref($err_or_som);

  $err_or_som = $self->prizm_command('CustomerIfService',
                                     'removeElementFromCustomer',
                                     0,
                                     $custnum,
                                     0,
                                     $svc->mac_addr,
                                    );

  return $err_or_som
    unless ref($err_or_som);

  '';
}

sub _export_replace {
  my( $self, $new, $old ) = ( shift, shift, shift );

  my $err_or_som = $self->prizm_command('NetworkIfService', 'getPrizmElements',
                                        [ 'MAC Address' ],
                                        [ $old->mac_addr ],
                                        [ '=' ],
                                       );
  return $err_or_som
    unless ref($err_or_som);

  return "Can't find prizm element for " . $old->mac_addr
    unless $err_or_som->result->[0];

  my %freeside2prizm = (  mac_addr     => 'MAC Address',
                          ip_addr      => 'Management IP',
                          latitude     => 'GPS Latitude',
                          longitude    => 'GPS Longitude',
                          altitude     => 'GPS Altitude',
                          authkey      => 'Authentication Key',
                       );
  
  my (@values);
  my (@names) = map { push @values, $new->$_; $freeside2prizm{$_} }
    grep { $old->$_ ne $new->$_ }
      grep { exists($freeside2prizm{$_}) }
        fields( 'svc_broadband' );

  if ($old->description ne $new->description) {
    my $cust_main = $old->cust_svc->cust_pkg->cust_main;
    my $name = defined($cust_main->dbdef_table->column('ship_last'))
             ? $cust_main->ship_name
             : $cust_main->name;
    push @values, $name . " " . $new->description;
    push @names, "Site Name";
  }

  my $element = $err_or_som->result->[0]->elementId;

  $err_or_som = $self->prizm_command('NetworkIfService', 'setElementConfig',
                                        [ $element ],
                                        \@names,
                                        \@values,
                                        0,
                                        1,
                                       );
  return $err_or_som
    unless ref($err_or_som);

  $err_or_som = $self->prizm_command('NetworkIfService', 'setElementConfigSet',
                                     [ $element ],
                                     $new->vlan_profile,
                                     0,
                                     1,
                                    )
    if $old->vlan_profile ne $new->vlan_profile;

  return $err_or_som
    unless ref($err_or_som);

  '';

}

sub _export_suspend {
  my( $self, $svc ) = ( shift, shift );

  my $err_or_som = $self->prizm_command('NetworkIfService', 'getPrizmElements',
                                        [ 'MAC Address' ],
                                        [ $svc->mac_addr ],
                                        [ '=' ],
                                       );
  return $err_or_som
    unless ref($err_or_som);

  return "Can't find prizm element for " . $svc->mac_addr
    unless $err_or_som->result->[0];

  $err_or_som = $self->prizm_command('NetworkIfService',
                                     'suspendNetworkElements',
                                     [ $err_or_som->result->[0]->elementId ],
                                     1,
                                     1,
                                    );

  return $err_or_som
    unless ref($err_or_som);

  '';

}

sub _export_unsuspend {
  my( $self, $svc ) = ( shift, shift );

  my $err_or_som = $self->prizm_command('NetworkIfService', 'getPrizmElements',
                                        [ 'MAC Address' ],
                                        [ $svc->mac_addr ],
                                        [ '=' ],
                                       );
  return $err_or_som
    unless ref($err_or_som);

  return "Can't find prizm element for " . $svc->mac_addr
    unless $err_or_som->result->[0];

  $err_or_som = $self->prizm_command('NetworkIfService',
                                     'activateNetworkElements',
                                     [ $err_or_som->result->[0]->elementId ],
                                     1,
                                     1,
                                    );

  return $err_or_som
    unless ref($err_or_som);

  '';

}

1;
