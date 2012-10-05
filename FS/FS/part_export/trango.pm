package FS::part_export::trango;

=head1 FS::part_export::trango

This export sends SNMP SETs to a router using the Net::SNMP package.  It requires the following custom fields to be defined on a router.  If any of the required custom fields are not present, then the export will exit quietly.

=head1 Required custom fields

=over 4

=item trango_address - IP address (or hostname) of the Trango AP.

=item trango_comm - R/W SNMP community of the Trango AP.

=item trango_ap_type - Trango AP Model.  Currently 'access5830' is the only supported option.

=back

=head1 Optional custom fields

=over 4

=item trango_baseid - Base ID of the Trango AP.  See L</"Generating SU IDs">.

=item trango_apid - AP ID of the Trango AP.  See L</"Generating SU IDs">.

=back

=head1 Generating SU IDs

This export will/must generate a unique SU ID for each service exported to a Trango AP.  It can be done such that SU IDs are globally unique, unique per Base ID, or unique per Base ID/AP ID pair.  This is accomplished by setting neither trango_baseid and trango_apid, only trango_baseid, or both trango_baseid and trango_apid, respectively.  An SU ID will be generated if the FS::svc_broadband virtual field specified by suid_field export option is unset, otherwise the existing value will be used.

=head1 Device Support

This export has been tested with the Trango Access5830 AP.


=cut


use strict;
use vars qw(@ISA %info $me $DEBUG $trango_mib $counter_dir);

use FS::UID qw(dbh datasrc);
use FS::Record qw(qsearch qsearchs);
use FS::part_export::snmp;

use Tie::IxHash;
use File::CounterFile;
use Data::Dumper qw(Dumper);

@ISA = qw(FS::part_export::snmp);

tie my %options, 'Tie::IxHash', (
  'suid_field' => {
    'label'   => 'Trango SU ID field',
    'default' => 'trango_suid',
    'notes'   => 'Name of the FS::svc_broadband virtual field that will contain the SU ID.',
  },
  'mac_field' => {
    'label'   => 'Trango MAC address field',
    'default' => '',
    'notes'   => 'Name of the FS::svc_broadband virtual field that will contain the SU\'s MAC address.',
  },
);

%info = (
  'svc'     => 'svc_broadband',
  'desc'    => 'Sends SNMP SETs to a Trango AP.',
  'options' => \%options,
  'no_machine' => 1,
  'notes'   => 'Requires Net::SNMP.  See the documentation for FS::part_export::trango for required virtual fields and usage information.',
);

$me= '[' .  __PACKAGE__ . ']';
$DEBUG = 1;

$trango_mib = {
  'access5830' => {
    'snmpversion' => 'snmpv1',
    'varbinds' => {
      'insert' => [
        { # sudbDeleteOrAddID
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.1',
          'type' => 'INTEGER',
          'value' => \&_trango_access5830_sudbDeleteOrAddId,
        },
        { # sudbAddMac
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.2',
          'type' => 'HEX_STRING',
          'value' => \&_trango_access5830_sudbAddMac,
        },
        { # sudbAddSU
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.7',
          'type' => 'INTEGER',
          'value' => 1,
        },
      ],
      'delete' => [
        { # sudbDeleteOrAddID
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.1',
          'type' => 'INTEGER',
          'value' => \&_trango_access5830_sudbDeleteOrAddId,
        },
        { # sudbDeleteSU
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.8',
          'type' => 'INTEGER',
          'value' => 1,
        },
      ],
      'replace' => [
        { # sudbDeleteOrAddID
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.1',
          'type' => 'INTEGER',
          'value' => \&_trango_access5830_sudbDeleteOrAddId,
        },
        { # sudbDeleteSU
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.8',
          'type' => 'INTEGER',
          'value' => 1,
        },
        { # sudbDeleteOrAddID
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.1',
          'type' => 'INTEGER',
          'value' => \&_trango_access5830_sudbDeleteOrAddId,
        },
        { # sudbAddMac
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.2',
          'type' => 'HEX_STRING',
          'value' => \&_trango_access5830_sudbAddMac,
        },
        { # sudbAddSU
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.7',
          'type' => 'INTEGER',
          'value' => 1,
        },
      ],
      'suspend' => [
        { # sudbDeleteOrAddID
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.1',
          'type' => 'INTEGER',
          'value' => \&_trango_access5830_sudbDeleteOrAddId,
        },
        { # sudbDeleteSU
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.8',
          'type' => 'INTEGER',
          'value' => 1,
        },
      ],
      'unsuspend' => [
        { # sudbDeleteOrAddID
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.1',
          'type' => 'INTEGER',
          'value' => \&_trango_access5830_sudbDeleteOrAddId,
        },
        { # sudbAddMac
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.2',
          'type' => 'HEX_STRING',
          'value' => \&_trango_access5830_sudbAddMac,
        },
        { # sudbAddSU
          'oid' => '1.3.6.1.4.1.5454.1.20.3.5.7',
          'type' => 'INTEGER',
          'value' => 1,
        },
      ],
    },
  },
};


sub _field_prefix { 'trango'; }

sub _req_router_fields {
  map {
    $_[0]->_field_prefix . '_' . $_
  } (qw(address comm ap_type suid_field));
}

sub _get_cmd_sub {

  return('FS::part_export::snmp::snmp_cmd');

}

sub _prepare_args {

  my ($self, $action, $router) = (shift, shift, shift);
  my ($svc_broadband) = shift;
  my $old = shift if $action eq 'replace';
  my $field_prefix = $self->_field_prefix;
  my $error;

  my $ap_type = $router->getfield($field_prefix . '_ap_type');

  unless (exists $trango_mib->{$ap_type}) {
    return "Unsupported Trango AP type '$ap_type'";
  }

  $error = $self->_check_suid(
    $action, $router, $svc_broadband, ($old) ? $old : ()
  );
  return $error if $error;

  $error = $self->_check_mac(
    $action, $router, $svc_broadband, ($old) ? $old : ()
  );
  return $error if $error;

  my $ap_mib = $trango_mib->{$ap_type};

  my $args = [
    '-hostname' => $router->getfield($field_prefix.'_address'),
    '-version' => $ap_mib->{'snmpversion'},
    '-community' => $router->getfield($field_prefix.'_comm'),
  ];

  my @varbindlist = ();

  foreach my $oid (@{$ap_mib->{'varbinds'}->{$action}}) {
    warn "[debug]$me Processing OID '" . $oid->{'oid'} . "'" if $DEBUG;
    my $value;
    if (ref($oid->{'value'}) eq 'CODE') {
      eval {
	$value = &{$oid->{'value'}}(
	  $self, $action, $router, $svc_broadband,
	  (($old) ? $old : ()),
	);
      };
      return "While processing OID '" . $oid->{'oid'} . "':" . $@
        if $@;
    } else {
      $value = $oid->{'value'};
    }

    warn "[debug]$me Value for OID '" . $oid->{'oid'} . "': " if $DEBUG;

    if (defined $value) { # Skip OIDs with undefined values.
      push @varbindlist, ($oid->{'oid'}, $oid->{'type'}, $value);
    }
  }


  push @$args, ('-varbindlist', @varbindlist);
  
  return('', $args);

}

sub _check_suid {

  my ($self, $action, $router, $svc_broadband) = (shift, shift, shift, shift);
  my $old = shift if $action eq 'replace';
  my $error;

  my $suid_field = $self->option('suid_field');
  unless (grep {$_ eq $suid_field} $svc_broadband->fields) {
    return "Missing Trango SU ID field.  "
      . "See the trango export options for more info.";
  }

  my $suid = $svc_broadband->getfield($suid_field);
  if ($action eq 'replace') {
    my $old_suid = $old->getfield($suid_field);

    if ($old_suid ne '' and $old_suid ne $suid) {
      return 'Cannot change Trango SU ID';
    }
  }

  if (not $suid =~ /^\d+$/ and $action ne 'delete') {
    my $new_suid = eval { $self->_get_next_suid($router); };
    return "Error while getting next Trango SU ID: $@" if ($@);

    warn "[debug]$me Got new SU ID: $new_suid" if $DEBUG;
    $svc_broadband->set($suid_field, $new_suid);

    #FIXME: Probably a bad hack.
    #       We need to update the SU ID field in the database.

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::svc_Common::noexport_hack = 1;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;

    my $svcnum = $svc_broadband->svcnum;

    my $old_svc = qsearchs('svc_broadband', { svcnum => $svcnum });
    unless ($old_svc) {
      return "Unable to retrieve svc_broadband with svcnum '$svcnum";
    }

    my $svcpart = $svc_broadband->svcpart
      ? $svc_broadband->svcpart
      : $svc_broadband->cust_svc->svcpart;

    my $new_svc = new FS::svc_broadband {
      $old_svc->hash,
      $suid_field => $new_suid,
      svcpart => $svcpart,
    };

    $error = $new_svc->check;
    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      return "Error while updating the Trango SU ID: $error" if $error;
    }

    warn "[debug]$me Updating svc_broadband with SU ID '$new_suid'...\n" .
      &Dumper($new_svc) if $DEBUG;

    $error = eval { $new_svc->replace($old_svc); };

    if ($@ or $error) {
      $error ||= $@;
      $dbh->rollback if $oldAutoCommit;
      return "Error while updating the Trango SU ID: $error" if $error;
    }

    $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  }

  return '';

}

sub _check_mac {

  my ($self, $action, $router, $svc_broadband) = (shift, shift, shift, shift);
  my $old = shift if $action eq 'replace';

  my $mac_field = $self->option('mac_field');
  unless (grep {$_ eq $mac_field} $svc_broadband->fields) {
    return "Missing Trango MAC address field.  "
      . "See the trango export options for more info.";
  }

  my $mac_addr = $svc_broadband->getfield($mac_field);
  unless (length(join('', $mac_addr =~ /[0-9a-fA-F]/g)) == 12) {
    return "Invalid Trango MAC address: $mac_addr";
  }

  return('');

}

sub _get_next_suid {

  my ($self, $router) = (shift, shift);

  my $counter_dir = '/usr/local/etc/freeside/export.'. datasrc . '/trango';
  my $baseid = $router->getfield('trango_baseid');
  my $apid = $router->getfield('trango_apid');

  my $counter_file_suffix = '';
  if ($baseid ne '') {
    $counter_file_suffix .= "_B$baseid";
    if ($apid ne '') {
      $counter_file_suffix .= "_A$apid";
    }
  }

  my $counter_file = $counter_dir . '/SUID' . $counter_file_suffix;

  warn "[debug]$me Using SUID counter file '$counter_file'";

  my $suid = eval {
    mkdir $counter_dir, 0700 unless -d $counter_dir;

    my $cf = new File::CounterFile($counter_file, 0);
    $cf->inc;
  };

  die "Error generating next Trango SU ID: $@" if (not $suid or $@);

  return($suid);

}



# Trango-specific subroutines for generating varbind values.
#
# All subs should die on error, and return undef to decline.  OIDs that
# decline will not be added to varbinds.

sub _trango_access5830_sudbDeleteOrAddId {

  my ($self, $action, $router) = (shift, shift, shift);
  my ($svc_broadband) = shift;
  my $old = shift if $action eq 'replace';

  my $suid = $svc_broadband->getfield($self->option('suid_field'));

  # Sanity check.
  unless ($suid =~ /^\d+$/) {
    if ($action eq 'delete') {
      # Silently ignore.  If we don't have a valid SU ID now, we probably
      # never did.
      return undef;
    } else {
      die "Invalid Trango SU ID '$suid'";
    }
  }

  return ($suid);

}

sub _trango_access5830_sudbAddMac {

  my ($self, $action, $router) = (shift, shift, shift);
  my ($svc_broadband) = shift;
  my $old = shift if $action eq 'replace';

  my $mac_addr = $svc_broadband->getfield($self->option('mac_field'));
  $mac_addr = join('', $mac_addr =~ /[0-9a-fA-F]/g);

  # Sanity check.
  die "Invalid Trango MAC address '$mac_addr'" unless (length($mac_addr)==12);

  return($mac_addr);

}


=head1 BUGS

Plenty, I'm sure.

=cut


1;
