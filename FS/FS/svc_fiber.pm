package FS::svc_fiber;

use strict;
use base qw( FS::svc_Common );
use FS::cust_svc;
use FS::hardware_type;
use FS::fiber_olt;
use FS::Record 'dbh';

=head1 NAME

FS::svc_fiber - Object methods for svc_fiber records

=head1 SYNOPSIS

  use FS::table_name;

  $record = new FS::table_name \%hash;
  $record = new FS::table_name { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_fiber object represents a fiber-to-the-premises service.  
FS::svc_fiber inherits from FS::svc_Common.  The following fields are
currently supported:

=over 4

=item svcnum - Primary key

=item oltnum - The Optical Line Terminal this service connects to (see
L<FS::fiber_olt>).

=item shelf - The shelf number on the OLT.

=item card - The card number on the OLT shelf.

=item olt_port - The port number on that card.

=item vlan - The VLAN number.

=item signal - Measured signal strength in dB.

=item speed_up - Measured uplink speed in Mbps.

=item speed_down - Measured downlink speed in Mbps.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new fiber service record.  To add it to the database, see L<"insert">.

=cut

sub table { 'svc_fiber'; }

sub table_info {
  {
    'name' => 'Fiber',
    'name_plural' => 'Fiber', # really the name of the ACL
    'longname_plural' => 'Fiber services',
    'sorts' => [ 'oltnum', ],
    'display_weight' => 74,
    'cancel_weight'  => 74,
    'fields' => {
      'oltnum'        => {
                          'label'        => 'OLT',
                          'type'         => 'select',
                          'select_table' => 'fiber_olt',
                          'select_key'   => 'oltnum',
                          'select_label' => 'oltname',
                          'disable_inventory' => 1,
                         },
      'shelf'         => {
                          'label' => 'Shelf',
                          'type'  => 'text',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                         },
      'card'          => {
                          'label' => 'Card',
                          'type'  => 'text',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                         },
      'olt_port'      => {
                          'label' => 'GPON port',
                          'type'  => 'text',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                         },
      # ODN circuit
      'circuit_id'    => {
                          'label' => 'ODN circuit',
                          'type'  => 'input-fiber_circuit',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                         },
      # ONT stuff
      'ont_id'        => {
                          'label' => 'ONT #',
                          'disable_select'    => 1,
                         },
      'ont_typenum'   => {
                          'label' => 'Device type',
                          'type'  => 'select-hardware',
                          'disable_select'    => 1,
                          'disable_default'   => 1,
                          'disable_inventory' => 1,
                         },
      'ont_serial'    => {
                          'label' => 'Serial number',
                          'disable_select'    => 1,
                         },
      'ont_port'      => {
                          'label' => 'GE port',
                          'type'  => 'text',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                         },
      'vlan'          => {
                          'label' => 'VLAN #',
                          'type'  => 'text',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                         },
      'signal'        => {
                          'label' => 'Signal strength (dB)',
                          'type'  => 'text',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                         },
      'speed_down'    => {
                          'label' => 'Download speed (Mbps)',
                          'type'  => 'text',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                         },
      'speed_up'      => {
                          'label' => 'Upload speed (Mbps)',
                          'type'  => 'text',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                         },
      'ont_install'   => {
                          'label' => 'ONT install location',
                          'type'  => 'text',
                          'disable_inventory' => 1,
                          'disable_select'    => 1,
                         },
    },
  };
}

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.
For svc_fiber, STRING can be a full or partial ONT serial number.

=cut

#or something more complicated if necessary
sub search_sql {
  my($class, $string) = @_;
  $string = dbh->quote('%' . $string . '%');
  "LOWER(svc_fiber.ont_serial) LIKE LOWER($string)";
}

=item label

Returns a description of this fiber service containing the ONT serial number
and the OLT name and port location.

=cut

sub label {
  my $self = shift;
  $self->ont_serial . ' @ ' . $self->fiber_olt->description . ' ' .
  join('-', $self->shelf, $self->card, $self->olt_port);
}

# nothing special for insert, delete, or replace

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  my $error =
       $self->ut_number('oltnum')
    || $self->ut_numbern('shelf')
    || $self->ut_numbern('card')
    || $self->ut_numbern('olt_port')
    || $self->ut_number('ont_id')
    || $self->ut_number('ont_typenum')
    || $self->ut_alphan('ont_serial')
    || $self->ut_alphan('ont_port')
    || $self->ut_numbern('vlan')
    || $self->ut_sfloatn('signal')
    || $self->ut_numbern('speed_up')
    || $self->ut_numbern('speed_down')
    || $self->ut_textn('ont_install')
  ;
  return $error if $error;

  $self->set('signal', sprintf('%.2f', $self->get('signal')));

  $self->SUPER::check;
}

=item ont_description

Returns the description of the ONT hardware, if there is one.

=cut

sub ont_description {
  my $self = shift;
  $self->ont_typenum ? $self->hardware_type->description : '';
}

=item search HASHREF

Returns a qsearch hash expression to search for parameters specified in
HASHREF.

Parameters are those in L<FS::svc_Common/search>, plus:

ont_typenum - the ONT L<FS::hardware_type> key

oltnum - the OLT L<FS::fiber_olt> key

shelf, card, olt_port - the OLT port location fields

vlan - the VLAN number

ont_serial - the ONT serial number

=cut

sub _search_svc {
  my ($class, $params, $from, $where) = @_;

  # make this simple: all of these are numeric fields, except that 0 means null
  foreach my $field (qw(ont_typenum oltnum shelf olt_port card vlan)) {
    if ( $params->{$field} =~ /^(\d+)$/ ) {
      push @$where, "COALESCE($field,0) = $1";
    }
  }
  if ( length($params->{ont_serial}) ) {
    my $string = dbh->quote('%'.$params->{ont_serial}.'%');
    push @$where, "LOWER(ont_serial) LIKE LOWER($string)";
  }

}

#stub still needed under 4.x+

sub hardware_type {
  my $self = shift;
  $self->ont_typenum ? FS::hardware_type->by_key($self->ont_typenum) : '';
}

=back

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

