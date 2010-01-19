package FS::part_export::prizm;

use vars qw(@ISA %info %options $DEBUG $me);
use Tie::IxHash;
use FS::Record qw(fields dbh);
use FS::part_export;

@ISA = qw(FS::part_export);
$DEBUG = 0;
$me = '[' . __PACKAGE__ . ']';

tie %options, 'Tie::IxHash',
  'url'      => { label => 'Northbound url', default=>'https://localhost:8443/prizm/nbi' },
  'user'     => { label => 'Northbound username', default=>'nbi' },
  'password' => { label => 'Password', default => '' },
  'ems'      => { label => 'Full EMS', type => 'checkbox' },
  'always_bam' => { label => 'Always activate/suspend authentication', type => 'checkbox' },
  'element_name_length' => { label => 'Size of siteName (best left blank)' },
;

my $notes = <<'EOT';
Real-time export of <b>svc_broadband</b>, <b>cust_pkg</b>, and <b>cust_main</b>
record data to Motorola
<a href="http://motorola.canopywireless.com/products/prizm/">Canopy Prizm
software</a> via the Northbound interface.<br><br>

Freeside will attempt to create an element in an existing network with the
values provided in svc_broadband.  Of particular interest are
<ul>
  <li> mac address - used to identify the element
  <li> vlan profile - an exact match for a vlan profiles defined in prizm
  <li> ip address - defines the management ip address of the prizm element
  <li> latitude - GPS latitude
  <li> longitude - GPS longitude
  <li> altitude - GPS altitude
</ul>

In addition freeside attempts to set the service plan name in prizm to the
name of the package in which the service resides.

The service is associated with a customer in prizm as well, and freeside
will create the customer should none already exist with import id matching
the freeside customer number.  The following fields are set.

<ul>
  <li> importId - the freeside customer number
  <li> customerType - freeside
  <li> customerName - the name associated with the freeside shipping address
  <li> address1 - the shipping address
  <li> address2
  <li> city
  <li> state
  <li> zipCode
  <li> country
  <li> workPhone - the daytime phone number
  <li> homePhone - the night phone number
  <li> freesideId - the freeside customer number
</ul>

  Additionally set on the element are
<ul>
  <li> Site Name - The shipping name followed by the service broadband description field
  <li> Site Location - the shipping address
  <li> Site Contact - the daytime and night phone numbers
</ul>

Freeside provisions, suspends, and unsuspends elements BAM only unless the
'Full EMS' checkbox is checked.<br><br>

When freeside provisions an element the siteName is copied internally by
prizm in such a manner that it is possible for the value to exceed the size
of the column used in the prizm database.  Therefore freeside truncates
by default this value to 50 characters.  It is thought that this
column is the account_name column of the element_user_account table.  It
may be possible to lift this limit by modifying the prizm database and
setting a new appropriate value on this export.  This is untested and
possibly harmful.

EOT

%info = (
  'svc'      => 'svc_broadband',
  'desc'     => 'Real-time export to Northbound Interface',
  'options'  => \%options,
  'nodomain' => 'Y',
  'notes'    => $notes,
);

sub prizm_command {
  my ($self,$namespace,$method) = (shift,shift,shift);

  eval "use Net::Prizm 0.04 qw(CustomerInfo PrizmElement);";
  die $@ if $@;

  my $prizm = new Net::Prizm (
    namespace => $namespace,
    url => $self->option('url'),
    user => $self->option('user'),
    password => $self->option('password'),
  );
  
  $prizm->$method(@_);
}

sub queued_prizm_command {  # subroutine
  my( $url, $user, $password, $namespace, $method, @args ) = @_;

  eval "use Net::Prizm 0.04 qw(CustomerInfo PrizmElement);";
  die $@ if $@;

  my $prizm = new Net::Prizm (
    namespace => $namespace,
    url => $url,
    user => $user,
    password => $password,
  );
  
  $err_or_som = $prizm->$method( @args);

  die $err_or_som
    unless ref($err_or_som);

  '';

}

sub _export_insert {
  my( $self, $svc ) = ( shift, shift );
  warn "$me: _export_insert called for export ". $self->exportnum.
    " on service ". $svc->svcnum. "\n"
    if $DEBUG;

  my $cust_main = $svc->cust_svc->cust_pkg->cust_main;

  my $err_or_som = $self->prizm_command('CustomerIfService', 'getCustomers',
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
    warn "$me: found customer $pcustomer in prizm\n" if $DEBUG;
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
    warn "$me: added customer $pcustomer to prizm\n" if $DEBUG;
  }
  warn "multiple prizm customers found for $cust_main->custnum"
    if scalar(@$pcustomer) > 1;

#  #kinda big question/expensive
#  $err_or_som = $self->prizm_command('NetworkIfService', 'getPrizmElements',
#                                     ['Network Default Gateway Address'],
#                                     [$svc->addr_block->ip_gateway],
#                                     ['='],
#                   );
#  return $err_or_som
#    unless ref($err_or_som);
#
#  return "No elements in network" unless exists $err_or_som->result->[0];

  my $networkid = 0;
#  for (my $i = 0; $i < $err_or_som->result->[0]->attributeNames; $i++) {
#    if ($err_or_som->result->[0]->attributeNames->[$i] eq "Network.ID"){
#      $networkid = $err_or_som->result->[0]->attributeValues->[$i];
#      last;
#    }
#  }

  my $performance_profile = $svc->performance_profile;
  $performance_profile ||= $svc->cust_svc->cust_pkg->part_pkg->pkg;

  my $element_name_length = 50;
  $element_name_length = $1
    if $self->option('element_name_length') =~ /^\s*(\d+)\s*$/;
  $err_or_som = $self->prizm_command('NetworkIfService', 'addProvisionedElement',
                                      $networkid,
                                      $svc->mac_addr,
                                      substr($name . " " . $svc->description,
                                             0, $element_name_length),
                                      $location,
                                      $contact,
                                      sprintf("%032X", $svc->authkey || 0),
                                      $performance_profile,
                                      $svc->vlan_profile,
                                      ($self->option('ems') ? 1 : 0 ),
                                     );
  return $err_or_som
    unless ref($err_or_som);
  warn "$me: added provisioned element to prizm\n" if $DEBUG;

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
                  $name . " " . $svc->description,
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
  warn "$me: set element configuration\n" if $DEBUG;

  $err_or_som = $self->prizm_command('NetworkIfService', 'setElementConfigSet',
                                     [ $element ],
                                     $svc->vlan_profile,
                                     0,
                                     1,
                                    );
  return $err_or_som
    unless ref($err_or_som);
  warn "$me: set element vlan profile\n" if $DEBUG;

  $err_or_som = $self->prizm_command('NetworkIfService', 'setElementConfigSet',
                                     [ $element ],
                                     $performance_profile,
                                     0,
                                     1,
                                    );
  return $err_or_som
    unless ref($err_or_som);
  warn "$me: set element configset (performance profile)\n" if $DEBUG;

  $err_or_som = $self->prizm_command('NetworkIfService',
                                     'activateNetworkElements',
                                     [ $element ],
                                     1,
                                     ( $self->option('ems') ? 1 : 0 ),
                                    );

  return $err_or_som
    unless ref($err_or_som);
  warn "$me: activated element\n" if $DEBUG;

  $err_or_som = $self->prizm_command('CustomerIfService',
                                     'addElementToCustomer',
                                     0,
                                     $cust_main->custnum,
                                     0,
                                     $svc->mac_addr,
                                    );

  return $err_or_som
    unless ref($err_or_som);
  warn "$me: added element to customer\n" if $DEBUG;

  '';
}

sub _export_delete {
  my( $self, $svc ) = ( shift, shift );

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_pkg = $svc->cust_svc->cust_pkg;

  my $depend = [];

  if ($cust_pkg) {
    my $queue = new FS::queue {
      'svcnum' => $svc->svcnum,
      'job'    => 'FS::part_export::prizm::queued_prizm_command',
    };
    my $error = $queue->insert(
      ( map { $self->option($_) }
            qw( url user password ) ),
      'CustomerIfService',
      'removeElementFromCustomer',
      0,
      $cust_pkg->custnum,
      0,
      $svc->mac_addr,
    );

    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

    push @$depend, $queue->jobnum;
  }

  my $err_or_queue =
    $self->queue_statuschange('deleteElement', $depend, $svc, 1);

  unless (ref($err_or_queue)) {
    $dbh->rollback if $oldAutoCommit;
    return $err_or_queue;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

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

  my $performance_profile = $new->performance_profile;
  $performance_profile ||= $new->cust_svc->cust_pkg->part_pkg->pkg;

  $err_or_som = $self->prizm_command('NetworkIfService', 'setElementConfigSet',
                                     [ $element ],
                                     $performance_profile,
                                     0,
                                     1,
                                    );
  return $err_or_som
    unless ref($err_or_som);

  '';

}

sub _export_suspend {
  my( $self, $svc ) = ( shift, shift );
  my $depend = [];
  my $ems = $self->option('ems') ? 1 : 0;
  my $err_or_queue = '';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $err_or_queue = 
     $self->queue_statuschange('suspendNetworkElements', [], $svc, 1, $ems);
  unless (ref($err_or_queue)) {
    $dbh->rollback if $oldAutoCommit;
    return $err_or_queue;
  }
  push @$depend, $err_or_queue->jobnum;

  if ($ems && $self->option('always_bam')) {
    $err_or_queue =
      $self->queue_statuschange('suspendNetworkElements', $depend, $svc, 1, 0);
    unless (ref($err_or_queue)) {
      $dbh->rollback if $oldAutoCommit;
      return $err_or_queue;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

sub _export_unsuspend {
  my( $self, $svc ) = ( shift, shift );
  my $depend = [];
  my $ems = $self->option('ems') ? 1 : 0;
  my $err_or_queue = '';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ($ems && $self->option('always_bam')) {
    $err_or_queue =
      $self->queue_statuschange('activateNetworkElements', [], $svc, 1, 0);
    unless (ref($err_or_queue)) {
      $dbh->rollback if $oldAutoCommit;
      return $err_or_queue;
    }
    push @$depend, $err_or_queue->jobnum;
  }

  $err_or_queue =
    $self->queue_statuschange('activateNetworkElements', $depend, $svc, 1, $ems);
  unless (ref($err_or_queue)) {
    $dbh->rollback if $oldAutoCommit;
    return $err_or_queue;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

sub export_links {
  my( $self, $svc, $arrayref ) = ( shift, shift, shift );

  push @$arrayref,
    '<A HREF="http://'. $svc->ip_addr. '" target="_blank">SM</A>';

  '';
}

sub queue_statuschange {
  my( $self, $method, $jobs, $svc, @args ) = @_;

  # already in a transaction and can't die here

  my $queue = new FS::queue {
    'svcnum' => $svc->svcnum,
    'job'    => 'FS::part_export::prizm::statuschange',
  };
  my $error = $queue->insert(
    ( map { $self->option($_) }
          qw( url user password ) ),
    $method,
    $svc->mac_addr,
    @args,
  );

  unless ($error) {                   # successful insertion
    foreach my $job ( @$jobs ) {
      $error ||= $queue->depend_insert($job);
    }
  }

  $error or $queue;
}

sub statuschange {  # subroutine
  my( $url, $user, $password, $method, $mac_addr, @args) = @_;

  eval "use Net::Prizm 0.04 qw(CustomerInfo PrizmElement);";
  die $@ if $@;

  my $prizm = new Net::Prizm (
    namespace => 'NetworkIfService',
    url => $url,
    user => $user,
    password => $password,
  );
  
  my $err_or_som = $prizm->getPrizmElements( [ 'MAC Address' ],
                                             [ $mac_addr ],
                                             [ '=' ],
                                           );
  die $err_or_som
    unless ref($err_or_som);

  die "Can't find prizm element for " . $mac_addr
    unless $err_or_som->result->[0];

  my $arg1;
  # yuck!
  if ($method =~ /suspendNetworkElements/ || $method =~ /activateNetworkElements/) {
    $arg1 = [ $err_or_som->result->[0]->elementId ];
  }else{
    $arg1 = $err_or_som->result->[0]->elementId;
  }
  $err_or_som = $prizm->$method( $arg1, @args );

  die $err_or_som
    unless ref($err_or_som);

  '';

}


1;
