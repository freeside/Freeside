package FS::part_export::broadband_snmp;

use strict;
use vars qw(%info $DEBUG);
use base 'FS::part_export';
use Net::SNMP qw(:asn1 :snmp);
use Tie::IxHash;

$DEBUG = 1;

my $me = '['.__PACKAGE__.']';

tie my %snmp_version, 'Tie::IxHash',
  v1  => SNMP_VERSION_1,
  v2c => SNMP_VERSION_2C,
  # 3 => 'v3' not implemented
;

tie my %snmp_type, 'Tie::IxHash',
  i => INTEGER,
  u => UNSIGNED32,
  s => OCTET_STRING,
  n => NULL,
  o => OBJECT_IDENTIFIER,
  t => TIMETICKS,
  a => IPADDRESS,
  # others not implemented yet
;

tie my %options, 'Tie::IxHash',
  'version' => { label=>'SNMP version', 
    type => 'select',
    options => [ keys %snmp_version ],
   },
  'community' => { label=>'Community', default=>'public' },
  (
    map { $_.'_command', 
          { label => ucfirst($_) . ' commands',
            type  => 'textarea',
            default => '',
          }
    } qw( insert delete replace suspend unsuspend )
  ),
  'ip_addr_change_to_new' => { 
    label=>'Send IP address changes to new address',
    type=>'checkbox'
  },
  'timeout' => { label=>'Timeout (seconds)' },
;

%info = (
  'svc'     => 'svc_broadband',
  'desc'    => 'Send SNMP requests to the service IP address',
  'options' => \%options,
  'weight'  => 10,
  'notes'   => <<'END'
Send one or more SNMP SET requests to the IP address registered to the service.
Enter one command per line.  Each command is a target OID, data type flag,
and value, separated by spaces.
The data type flag is one of the following:
<font size="-1"><ul>
<li><i>i</i> = INTEGER</li>
<li><i>u</i> = UNSIGNED32</li>
<li><i>s</i> = OCTET-STRING (as ASCII)</li>
<li><i>a</i> = IPADDRESS</li>
<li><i>n</i> = NULL</li></ul>
The value may interpolate fields from svc_broadband by prefixing the field 
name with <b>$</b>, or <b>$new_</b> and <b>$old_</b> for replace operations.
The value may contain whitespace; quotes are not necessary.<br>
<br>
For example, to set the SNMPv2-MIB "sysName.0" object to the string 
"svc_broadband" followed by the service number, use the following 
command:<br>
<pre>1.3.6.1.2.1.1.5.0 s svc_broadband$svcnum</pre><br>
END
);

sub export_insert {
  my $self = shift;
  $self->export_command('insert', @_);
}

sub export_delete {
  my $self = shift;
  $self->export_command('delete', @_);
}

sub export_replace {
  my $self = shift;
  $self->export_command('replace', @_);
}

sub export_suspend {
  my $self = shift;
  $self->export_command('suspend', @_);
}

sub export_unsuspend {
  my $self = shift;
  $self->export_command('unsuspend', @_);
}

sub export_command {
  my $self = shift;
  my ($action, $svc_new, $svc_old) = @_;

  my $command_text = $self->option($action.'_command');
  return if !length($command_text);

  warn "$me parsing ${action}_command:\n" if $DEBUG;
  my @commands;
  foreach (split /\n/, $command_text) {
    my ($oid, $type, $value) = split /\s/, $_, 3;
    $oid =~ /^(\d+\.)*\d+$/ or die "invalid OID '$oid'\n";
    my $typenum = $snmp_type{$type} or die "unknown data type '$type'\n";
    $value = '' if !defined($value); # allow sending an empty string
    $value = $self->substitute($value, $svc_new, $svc_old);
    warn "$me     $oid $type $value\n" if $DEBUG;
    push @commands, $oid, $typenum, $value;
  }

  my $ip_addr = $svc_new->ip_addr;
  # ip address change: send to old address unless told otherwise
  if ( defined $svc_old and ! $self->option('ip_addr_change_to_new') ) {
    $ip_addr = $svc_old->ip_addr;
  }
  warn "$me opening session to $ip_addr\n" if $DEBUG;

  my %opt = (
    -hostname => $ip_addr,
    -community => $self->option('community'),
    -timeout => $self->option('timeout') || 20,
  );
  my $version = $self->option('version');
  $opt{-version} = $snmp_version{$version} or die 'invalid version';
  $opt{-varbindlist} = \@commands; # just for now

  $self->snmp_queue( $svc_new->svcnum, %opt );
}

sub snmp_queue {
  my $self = shift;
  my $svcnum = shift;
  my $queue = new FS::queue {
    'svcnum'  => $svcnum,
    'job'     => 'FS::part_export::broadband_snmp::snmp_request',
  };
  $queue->insert(@_);
}

sub snmp_request {
  my %opt = @_;
  my $varbindlist = delete $opt{-varbindlist};
  my ($session, $error) = Net::SNMP->session(%opt);
  die "Couldn't create SNMP session: $error" if !$session;

  warn "$me sending SET request\n" if $DEBUG;
  my $result = $session->set_request( -varbindlist => $varbindlist );
  $error = $session->error();
  $session->close();

  if (!defined $result) {
    die "SNMP request failed: $error\n";
  }
}

sub substitute {
  # double-quote-ish interpolation of service fields
  # accepts old_ and new_ for replace actions, like shellcommands
  my $self = shift;
  my ($value, $svc_new, $svc_old) = @_;
  foreach my $field ( $svc_new->fields ) {
    my $new_val = $svc_new->$field;
    $value =~ s/\$(new_)?$field/$new_val/g;
    if ( $svc_old ) { # replace only
      my $old_val = $svc_old->$field;
      $value =~ s/\$old_$field/$old_val/g;
    }
  }
  $value;
}

1;
