package FS::part_export::broadband_snmp;

use strict;
use vars qw(%info $DEBUG);
use base 'FS::part_export';
use SNMP;
use Tie::IxHash;

$DEBUG = 0;

my $me = '['.__PACKAGE__.']';

tie my %snmp_version, 'Tie::IxHash',
  v1  => '1',
  v2c => '2c',
  # v3 unimplemented
;

#tie my %snmp_type, 'Tie::IxHash',
#  i => INTEGER,
#  u => UNSIGNED32,
#  s => OCTET_STRING,
#  n => NULL,
#  o => OBJECT_IDENTIFIER,
#  t => TIMETICKS,
#  a => IPADDRESS,
#  # others not implemented yet
#;

tie my %options, 'Tie::IxHash',
  'version' => { label=>'SNMP version', 
    type => 'select',
    options => [ keys %snmp_version ],
   },
  'community' => { label=>'Community', default=>'public' },

  'action' => { multiple=>1 },
  'oid'    => { multiple=>1 },
  'value'  => { multiple=>1 },

  'ip_addr_change_to_new' => { 
    label=>'Send IP address changes to new address',
    type=>'checkbox'
  },
  'timeout' => { label=>'Timeout (seconds)' },
;

%info = (
  'svc'     => 'svc_broadband',
  'desc'    => 'Send SNMP requests to the service IP address',
  'config_element' => '/edit/elements/part_export/broadband_snmp.html',
  'options' => \%options,
  'no_machine' => 1,
  'weight'  => 10,
  'notes'   => <<'END'
Send one or more SNMP SET requests to the IP address registered to the service.
The value may interpolate fields from svc_broadband by prefixing the field 
name with <b>$</b>, or <b>$new_</b> and <b>$old_</b> for replace operations.
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

  my @a = split("\n", $self->option('action'));
  my @o = split("\n", $self->option('oid'));
  my @v = split("\n", $self->option('value'));
  my @commands;
  warn "$me parsing $action commands:\n" if $DEBUG;
  while (@a) {
    my $oid = shift @o;
    my $value = shift @v;
    next unless shift(@a) eq $action; # ignore commands for other actions
    $value = $self->substitute($value, $svc_new, $svc_old);
    warn "$me     $oid :=$value\n" if $DEBUG;
    push @commands, $oid, $value;
  }

  my $ip_addr = $svc_new->ip_addr;
  # ip address change: send to old address unless told otherwise
  if ( defined $svc_old and ! $self->option('ip_addr_change_to_new') ) {
    $ip_addr = $svc_old->ip_addr;
  }
  warn "$me opening session to $ip_addr\n" if $DEBUG;

  my %opt = (
    DestHost  => $ip_addr,
    Community => $self->option('community'),
    Timeout   => ($self->option('timeout') || 20) * 1000,
  );
  my $version = $self->option('version');
  $opt{Version} = $snmp_version{$version} or die 'invalid version';
  $opt{VarList} = \@commands; # for now

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
  my $flatvarlist = delete $opt{VarList};
  my $session = SNMP::Session->new(%opt);

  warn "$me sending SET request\n" if $DEBUG;

  my @varlist;
  while (@$flatvarlist) {
    my @this = splice(@$flatvarlist, 0, 2);
    push @varlist, [ $this[0], 0, $this[1], undef ];
    # XXX new option to choose the IID (array index) of the object?
  }

  $session->set(\@varlist);
  my $error = $session->{ErrorStr};

  if ( $session->{ErrorNum} ) {
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

sub _upgrade_exporttype {
  eval 'use FS::Record qw(qsearch qsearchs)';
  # change from old style with numeric oid, data type flag, and value
  # on consecutive lines
  foreach my $export (qsearch('part_export',
                      { exporttype => 'broadband_snmp' } ))
  {
    # for the new options
    my %new_options = (
      'action' => [],
      'oid'    => [],
      'value'  => [],
    );
    foreach my $action (qw(insert replace delete suspend unsuspend)) {
      my $old_option = qsearchs('part_export_option',
                      { exportnum   => $export->exportnum,
                        optionname  => $action.'_command' } );
      next if !$old_option;
      my $text = $old_option->optionvalue;
      my @commands = split("\n", $text);
      foreach (@commands) {
        my ($oid, $type, $value) = split /\s/, $_, 3;
        push @{$new_options{action}}, $action;
        push @{$new_options{oid}},    $oid;
        push @{$new_options{value}},   $value;
      }
      my $error = $old_option->delete;
      warn "error migrating ${action}_command option: $error\n" if $error;
    }
    foreach (keys(%new_options)) {
      my $new_option = FS::part_export_option->new({
          exportnum   => $export->exportnum,
          optionname  => $_,
          optionvalue => join("\n", @{ $new_options{$_} })
      });
      my $error = $new_option->insert;
      warn "error inserting '$_' option: $error\n" if $error;
    }
  } #foreach $export
  '';
}

1;
