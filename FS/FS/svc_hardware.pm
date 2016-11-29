package FS::svc_hardware;
use base qw( FS::svc_Common );

use strict;
use vars qw( $conf );
use FS::Record qw( qsearchs ); #qsearch qsearchs );
use FS::hardware_status;
use FS::Conf;

FS::UID->install_callback(sub { $conf = FS::Conf->new; });

=head1 NAME

FS::svc_hardware - Object methods for svc_hardware records

=head1 SYNOPSIS

  use FS::svc_hardware;

  $record = new FS::svc_hardware \%hash;
  $record = new FS::svc_hardware { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_hardware object represents an equipment installation, such as 
a wireless broadband receiver, satellite antenna, or DVR.  FS::svc_hardware 
inherits from FS::svc_Common.

The following fields are currently supported:

=over 4

=item svcnum - Primary key

=item typenum - Device type number (see L<FS::hardware_type>)

=item ip_addr - IP address

=item hw_addr - Hardware address

=item serial - Serial number

=item smartcard - Smartcard number, for devices that use a smartcard

=item statusnum - Service status (see L<FS::hardware_status>)

=item note - Installation notes: location on property, physical access, etc.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new svc_hardware object.

=cut

sub table { 'svc_hardware'; }

sub table_info {
  my %opts = ( 'type' => 'text', 'disable_select' => 1 );
  {
    'name'           => 'Hardware', #?
    'name_plural'    => 'Hardware',
    'display_weight' => 59,
    'cancel_weight'  => 86,
    'manual_require' => 1,
    'fields' => {
      'svcnum'    => { label => 'Service' },
      'typenum'   => { label => 'Device type',
                       type  => 'select-hardware',
                       disable_select    => 1,
                       disable_fixed     => 1,
                       disable_default   => 1,
                       disable_inventory => 1,
                       required => 1,
                     },
      'serial'    => { label => 'Serial number', %opts },
      'hw_addr'   => { label => 'Hardware address', %opts },
      'ip_addr'   => { label => 'IP address', %opts },
      'smartcard' => { label => 'Smartcard #', %opts },
      'statusnum' => { label => 'Service status', 
                       type  => 'select',
                       select_table => 'hardware_status',
                       select_key   => 'statusnum',
                       select_label => 'label',
                       disable_inventory => 1,
                     },
      'note'      => { label => 'Installation notes', %opts },
    }
  }
}

sub search_sql {
  my ($class, $string) = @_;
  my @where = ();

  if ( $string =~ /^[\d\.:]+$/ ) {
    # if the string isn't an IP address, this will waste several seconds
    # attempting a DNS lookup.  so try to filter those out.
    my $ip = NetAddr::IP->new($string);
    if ( $ip ) {
      push @where, $class->search_sql_field('ip_addr', $ip->addr);
    }
  }
  
  if ( $string =~ /^(\w+)$/ ) {
    push @where, 'LOWER(svc_hardware.serial) LIKE \'%'.lc($string).'%\'';
  }

  if ( $string =~ /^([0-9A-Fa-f]|\W)+$/ ) {
    my $hex = uc($string);
    $hex =~ s/\W//g;
    push @where, 'svc_hardware.hw_addr LIKE \'%'.$hex.'%\'';
  }

  if ( @where ) {
    '(' . join(' OR ', @where) . ')';
  } else {
    '1 = 0'; #false
  }
}

sub label {
  my $self = shift;
  my $part_svc = $self->cust_svc->part_svc;
  my @label = ();
  if (my $type = $self->hardware_type) {
    my $typenum_label = $part_svc->part_svc_column('typenum');
    push @label, ( $typenum_label && $typenum_label->columnlabel || 'Type:' ).
                 $type->description;
  }
  if (my $ser = $self->serial) {
    my $serial_label = $part_svc->part_svc_column('serial');
    push @label, ( $serial_label && $serial_label->columnlabel || 'Serial#' ).
                 $ser;
  }
  if (my $mac = $self->display_hw_addr) {
    my $hw_addr_label = $part_svc->part_svc_column('hw_addr');
    push @label, ( $hw_addr_label && $hw_addr_label->columnlabel || 'MAC:').
    $mac;
  }
  return join(', ', @label);
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid service.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;
  my $conf = FS::Conf->new;

  my $x = $self->setfixed;
  return $x unless ref $x;

  my $hw_addr = $self->getfield('hw_addr');
  $hw_addr = join('', split(/[_\W]/, $hw_addr));
  if ( $conf->exists('svc_hardware-check_mac_addr') ) {
    $hw_addr = uc($hw_addr);
    $hw_addr =~ /^[0-9A-F]{12}$/ 
      or return "Illegal (MAC address) '".$self->getfield('hw_addr')."'";
  }
  $self->setfield('hw_addr', $hw_addr);

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_foreign_key('typenum', 'hardware_type', 'typenum')
    || $self->ut_ip46n('ip_addr')
    || $self->ut_alphan('hw_addr')
    || $self->ut_alphan('serial')
    || $self->ut_alphan('smartcard')
    || $self->ut_foreign_keyn('statusnum', 'hardware_status', 'statusnum')
    || $self->ut_anything('note')
  ;
  return $error if $error;

  if ( !length($self->getfield('hw_addr')) 
        and !length($self->getfield('serial')) ) {
    return 'Serial number or hardware address required';
  }
 
  $self->SUPER::check;
}

=item hardware_type

Returns the L<FS::hardware_type> object associated with this installation.

=item status_label

Returns the 'label' field of the L<FS::hardware_status> object associated 
with this installation.

=cut

sub status_label {
  my $self = shift;
  my $status = qsearchs('hardware_status', { 'statusnum' => $self->statusnum })
    or return '';
  $status->label;
}

=item display_hw_addr

Returns the 'hw_addr' field, formatted as a MAC address if the
'svc_hardware-check_mac_addr' option is enabled.

=cut

sub display_hw_addr {
  my $self = shift;
  ($conf->exists('svc_hardware-check_mac_addr') ? 
    join(':', $self->hw_addr =~ /../g) : $self->hw_addr)
}

=back

=head1 SEE ALSO

L<FS::Record>, L<FS::svc_Common>, schema.html from the base documentation.

=cut

1;

