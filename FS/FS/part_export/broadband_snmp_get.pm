package FS::part_export::broadband_snmp_get;

use strict;
use vars qw(%info $DEBUG);
use base 'FS::part_export';
use SNMP;
use Tie::IxHash;

tie my %snmp_version, 'Tie::IxHash',
  v1  => '1',
  v2c => '2c'
  # v3 unimplemented
;

tie my %options, 'Tie::IxHash',
  'snmp_version' => {
    label=>'SNMP version', 
    type => 'select',
    options => [ keys %snmp_version ],
   },
  'snmp_community' => { 'label'=>'Community', 'default'=>'public' },
  'snmp_timeout' => { label=>'Timeout (seconds)', 'default'=>1 },
  'snmp_oid' => { label=>'Object ID', multiple=>1 },
;

%info = (
  'svc'     => 'svc_broadband',
  'desc'    => 'Enable interface display of realtime SNMP get requests to service IP address',
  'config_element' => '/edit/elements/part_export/broadband_snmp_get.html',
  'options' => \%options,
  'no_machine' => 1,
  'notes'   => <<'END',
Use this export to configure the community and object ids for displaying realtime 
SNMP data from the service IP address when viewing a provisioned service.  Timeout is
per object, and should be small enough for realtime use.  This export takes no action 
during provisioning itself;  it is expected that snmp will be separately
configured on the service machine.
END
);

sub export_insert { ''; }
sub export_replace { ''; }
sub export_delete { ''; }
sub export_suspend { ''; }
sub export_unsuspend { ''; }

=pod

=head1 NAME

FS::part_export::broadband_snmp_get

=head1 SYNOPSIS

Configuration for realtime snmp requests to svc_broadband IP address

=head1 METHODS

=cut

=over 4

=item snmp_results SVC

Request statistics from SVC ip address.  Returns an array of hashes with keys 

objectID

label

value

error - error when attempting to load this object

=cut

sub snmp_results {
  my ($self, $svc) = @_;
  my $host = $svc->ip_addr;
  my $comm = $self->option('snmp_community');
  my $vers = $self->option('snmp_version');
  my $time = ($self->option('snmp_timeout') || 1) * 1000;
  my @oids = split("\n", $self->option('snmp_oid'));
  my %connect = (
    'DestHost'  => $host,
    'Community' => $comm,
    'Version'   => $vers,
    'Timeout'   => $time,
  );
  my $snmp = new SNMP::Session(%connect);
  return { 'error' => 'Error creating SNMP session' } unless $snmp;
  return { 'error' => $snmp->{'ErrorStr'} } if $snmp->{'ErrorStr'};
  my @out;
  foreach my $oid (@oids) {
    $oid = $SNMP::MIB{$oid}->{'objectID'} if $SNMP::MIB{$oid};
    my $value = $snmp->get($oid.'.0');
    if ($snmp->{'ErrorStr'}) {
      push @out, { 'error' => $snmp->{'ErrorStr'} };
      next;
    }
    my %result = map { $_ => $SNMP::MIB{$oid}{$_} } qw( objectID label value );
    $result{'value'} = $value;
    push @out, \%result;
  }
  return @out;      
}

=back

=cut

1;

