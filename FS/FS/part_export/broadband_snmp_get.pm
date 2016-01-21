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
Display broadband service status information via SNMP.  Timeout is
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

Request statistics from SVC ip address.  Returns an array of hashrefs with keys 

error - error message

objectID - dotted decimal fully qualified OID

label - leaf textual identifier (e.g., 'sysDescr')

values - arrayref of arrayrefs describing values, [<obj>, <iid>, <val>, <type>]

=cut

sub snmp_results {
  my ($self, $svc) = @_;
  my $host = $svc->ip_addr;
  my $comm = $self->option('snmp_community');
  my $vers = $self->option('snmp_version');
  my $time = ($self->option('snmp_timeout') || 1) * 1000000;
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
    my @values;
    if ($vers eq '1') {
      my $varbind = new SNMP::Varbind [$oid];
      my $max = 1000; #sanity check
      while ($max > 0 and $snmp->getnext($varbind)) {
        last if $snmp->{'ErrorStr'};
        last unless $SNMP::MIB{$varbind->[0]}; # does this happen?
        my $nextoid = $SNMP::MIB{$varbind->[0]}->{'objectID'};
        last unless $nextoid =~ /^$oid/;
        $max--;
        push @values, new SNMP::Varbind [ @$varbind ];
      }
    } else {
      # not clear on what max-repeaters (25) does, plucked value from example code
      # but based on testing, it isn't capping number of returned values
      @values = $snmp->bulkwalk(0,25,$oid);
    }
    if ($snmp->{'ErrorStr'} || !@values) {
      push @out, { 'error' => $snmp->{'ErrorStr'} || 'No values retrieved' };
      next;
    }
    my %result = map { $_ => $SNMP::MIB{$oid}{$_} } qw( objectID label );
    # unbless @values, for ease of JSON encoding
    $result{'values'} = [];
    foreach my $value (@values) {
      push @{$result{'values'}}, [ map { $_ } @$value ];
    }
    push @out, \%result;
  }
  return @out;      
}

=back

=cut

1;

