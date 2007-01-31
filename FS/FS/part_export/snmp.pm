package FS::part_export::snmp;

=head1 FS::part_export::snmp

This export sends SNMP SETs to a router using the Net::SNMP package.  It requires the following custom fields to be defined on a router.  If any of the required custom fields are not present, then the export will exit quietly.

=head1 Required custom fields

=over 4

=item snmp_address - IP address (or hostname) of the router/agent

=item snmp_comm - R/W SNMP community of the router/agent

=item snmp_version - SNMP version of the router/agent

=back

=head1 Optional custom fields

=over 4

=item snmp_cmd_insert - SNMP SETs to perform on insert.  See L</Formatting>

=item snmp_cmd_replace - SNMP SETs to perform on replace.  See L</Formatting>

=item snmp_cmd_delete - SNMP SETs to perform on delete.  See L</Formatting>

=item snmp_cmd_suspend - SNMP SETs to perform on suspend.  See L</Formatting>

=item snmp_cmd_unsuspend - SNMP SETs to perform on unsuspend.  See L</Formatting>

=back

=head1 Formatting

The values for the snmp_cmd_* fields should be formatted as follows:

<OID>|<Data Type>|<expr>[||<OID>|<Data Type>|<expr>[...]]

=over 4

=item OID - SNMP object ID (ex. 1.3.6.1.4.1.1.20).  If the OID string starts with a '.', then the Private Enterprise OID (1.3.6.1.4.1) is prepended.

=item Data Type - SNMP data types understood by L<Net::SNMP>, as well as HEX_STRING for convenience.  ex. INTEGER, OCTET_STRING, IPADDRESS, ...

=item expr - Expression to be eval'd by freeside.  By default, the expression is double quoted and eval'd with all FS::svc_broadband fields available as scalars (ex. $svcnum, $ip_addr, $speed_up).  However, if the expression contains a non-escaped double quote, the expression is eval'd without being double quoted.  In this case, the expression must be a block of valid perl code that returns the desired value.

You must escape non-delimiter pipes ("|") with a backslash.

=back

=head1 Examples

This is an example for exporting to a Trango Access5830 AP.  Newlines inserted for clarity.

=over 4

=item snmp_cmd_delete - 

1.3.6.1.4.1.5454.1.20.3.5.1|INTEGER|50||
1.3.6.1.4.1.5454.1.20.3.5.8|INTEGER|1|

=item snmp_cmd_insert - 

1.3.6.1.4.1.5454.1.20.3.5.1|INTEGER|50||
1.3.6.1.4.1.5454.1.20.3.5.2|HEX_STRING|join("",$radio_addr =~ /[0-9a-fA-F]{2}/g)||
1.3.6.1.4.1.5454.1.20.3.5.7|INTEGER|1|

=item snmp_cmd_replace - 

1.3.6.1.4.1.5454.1.20.3.5.1|INTEGER|50||
1.3.6.1.4.1.5454.1.20.3.5.8|INTEGER|1||1.3.6.1.4.1.5454.1.20.3.5.1|INTEGER|50||
1.3.6.1.4.1.5454.1.20.3.5.2|HEX_STRING|join("",$new_radio_addr =~ /[0-9a-fA-F]{2}/g)||
1.3.6.1.4.1.5454.1.20.3.5.7|INTEGER|1|

=back

=cut


use strict;
use vars qw(@ISA %info $me $DEBUG);
use Tie::IxHash;
use FS::Record qw(qsearch qsearchs);
use FS::part_export;
use FS::part_export::router;

@ISA = qw(FS::part_export::router);

tie my %options, 'Tie::IxHash', ();

%info = (
  'svc'     => 'svc_broadband',
  'desc'    => 'Sends SNMP SETs to an SNMP agent.',
  'options' => \%options,
  'notes'   => 'Requires Net::SNMP.  See the documentation for FS::part_export::snmp for required virtual fields and usage information.',
);

$me= '[' .  __PACKAGE__ . ']';
$DEBUG = 1;


sub _field_prefix { 'snmp'; }

sub _req_router_fields {
  map {
    $_[0]->_field_prefix . '_' . $_
  } (qw(address comm version));
}

sub _get_cmd_sub {

  my ($self, $svc_broadband, $router) = (shift, shift, shift);

  return(ref($self) . '::snmp_cmd');

}

sub _prepare_args {

  my ($self, $action, $router) = (shift, shift, shift);
  my ($svc_broadband) = shift;
  my $old;
  my $field_prefix = $self->_field_prefix;

  if ($action eq 'replace') { $old = shift; }

  my $raw_cmd = $router->getfield("${field_prefix}_cmd_${action}");
  unless ($raw_cmd) {
    warn "[debug]$me router custom field '${field_prefix}_cmd_$action' "
      . "is not defined." if $DEBUG;
    return '';
  }

  my $args = [
    '-hostname' => $router->getfield($field_prefix.'_address'),
    '-version' => $router->getfield($field_prefix.'_version'),
    '-community' => $router->getfield($field_prefix.'_comm'),
  ];

  my @varbindlist = ();

  foreach my $snmp_cmd ($raw_cmd =~ m/(.*?[^\\])(?:\|\||$)/g) {

    warn "[debug]$me snmp_cmd is '$snmp_cmd'" if $DEBUG;

    my ($oid, $type, $expr) = $snmp_cmd =~ m/(.*?[^\\])(?:\||$)/g;

    if ($oid =~ /^([\d\.]+)$/) {
      $oid = $1;
      $oid = ($oid =~ /^\./) ? '1.3.6.1.4.1' . $oid : $oid;
    } else {
      return "Invalid SNMP OID '$oid'";
    }

    if ($type =~ /^([A-Z_\d]+)$/) {
      $type = $1;
    } else {
      return "Invalid SNMP ASN.1 type '$type'";
    }

    if ($expr =~ /^(.*)$/) {
      $expr = $1;
    } else {
      return "Invalid expression '$expr'";
    }

    {
      no strict 'vars';
      no strict 'refs';

      if ($action eq 'replace') {
	${"old_$_"} = $old->getfield($_) foreach $old->fields;
	${"new_$_"} = $svc_broadband->getfield($_) foreach $svc_broadband->fields;
	$expr = ($expr =~/[^\\]"/) ? eval($expr) : eval(qq("$expr"));
      } else {
	${$_} = $svc_broadband->getfield($_) foreach $svc_broadband->fields;
	$expr = ($expr =~/[^\\]"/) ? eval($expr) : eval(qq("$expr"));
      }
      return $@ if $@;
    }

    push @varbindlist, ($oid, $type, $expr);

  }

  push @$args, ('-varbindlist', @varbindlist);
  
  return('', $args);

}

sub snmp_cmd {
  eval "use Net::SNMP;";
  die $@ if $@;

  my %args = ();
  my @varbindlist = ();
  while (scalar(@_)) {
    my $key = shift;
    if ($key eq '-varbindlist') {
      push @varbindlist, @_;
      last;
    } else {
      $args{$key} = shift;
    }
  }

  my $i = 0;
  while ($i*3 < scalar(@varbindlist)) {
    my $type_index = ($i*3)+1;
    my $type_name = $varbindlist[$type_index];

    # Implementing HEX_STRING outselves since Net::SNMP doesn't.  Ewwww!
    if ($type_name eq 'HEX_STRING') {
      my $value_index = $type_index + 1;
      $type_name = 'OCTET_STRING';
      $varbindlist[$value_index] = pack('H*', $varbindlist[$value_index]);
    }

    my $type = eval "Net::SNMP::$type_name";
    if ($@ or not defined $type) {
      warn $@ if $DEBUG;
      die "snmp_cmd error: Unable to lookup type '$type_name'";
    }

    $varbindlist[$type_index] = $type;
  } continue {
    $i++;
  }

  my ($snmp, $error) = Net::SNMP->session(%args);
  die "snmp_cmd error: $error" unless($snmp);

  my $res = $snmp->set_request('-varbindlist' => \@varbindlist);
  unless($res) {
    $error = $snmp->error;
    $snmp->close;
    die "snmp_cmd error: " . $error;
  }

  $snmp->close;

  return '';

}


=head1 BUGS

Plenty, I'm sure.

=cut

1;
