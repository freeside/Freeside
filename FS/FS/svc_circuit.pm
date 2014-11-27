package FS::svc_circuit;

use strict;
use base qw(
  FS::svc_IP_Mixin
  FS::MAC_Mixin
  FS::svc_Common
);
use FS::Record qw( qsearch qsearchs );
use FS::circuit_provider;
use FS::circuit_type;
use FS::circuit_termination;

=head1 NAME

FS::svc_circuit - Object methods for svc_circuit records

=head1 SYNOPSIS

  use FS::svc_circuit;

  $record = new FS::svc_circuit \%hash;
  $record = new FS::svc_circuit { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_circuit object represents a telecom circuit service (other than 
an analog phone line, which is svc_phone, or a DSL Internet connection, 
which is svc_dsl).  FS::svc_circuit inherits from FS::svc_IP_Mixin,
FS::MAC_Mixin, and FS::svc_Common.  The following fields are currently
supported:

=over 4

=item svcnum - primary key; see also L<FS::cust_svc>

=item typenum - circuit type (such as DS1, DS1-PRI, DS3, OC3, etc.); foreign
key to L<FS::circuit_type>.

=item providernum - circuit provider (telco); foreign key to 
L<FS::circuit_provider>.

=item termnum - circuit termination type; foreign key to 
L<FS::circuit_termination>

=item circuit_id - circuit ID string defined by the provider

=item desired_due_date - the requested date for completion of the circuit
order

=item due_date - the provider's committed date for completion of the circuit
order

=item vendor_order_id - the provider's order number

=item vendor_qual_id - the qualification number, if a qualification was 
performed

=item vendor_order_type -

=item vendor_order_status - the order status: ACCEPTED, PENDING, COMPLETED,
etc.

=item endpoint_ip_addr - the IP address of the endpoint equipment, if any. 
This will be validated as an IP address but not assigned from managed address
space or checked for uniqueness.

=item endpoint_mac_addr - the MAC address of the endpoint.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new circuit service.  To add the record to the database, see 
L<"insert">.

=cut

sub table { 'svc_circuit'; }

sub table_info {
  my %dis = ( disable_default => 1, disable_fixed => 1,
              disabled_inventory => 1, disable_select => 1 );

  tie my %fields, 'Tie::IxHash', (
    'svcnum'            => 'Service',
    'providernum'       => {
                              label         => 'Provider',
                              type          => 'select',
                              select_table  => 'circuit_provider',
                              select_key    => 'providernum',
                              select_label  => 'provider',
                              disable_inventory => 1,
                           },
    'typenum'           => {
                              label         => 'Circuit type',
                              type          => 'select',
                              select_table  => 'circuit_type',
                              select_key    => 'typenum',
                              select_label  => 'typename',
                              disable_inventory => 1,
                           },
    'termnum'           => {
                              label         => 'Termination type',
                              type          => 'select',
                              select_table  => 'circuit_termination',
                              select_key    => 'termnum',
                              select_label  => 'termination',
                              disable_inventory => 1,
                           },
    'circuit_id'        => { label => 'Circuit ID', %dis },
    'desired_due_date'  => { label => 'Desired due date',
                             %dis
                           },
    'due_date'          => { label => 'Due date',
                             %dis
                           },
    'vendor_order_id'   => { label => 'Vendor order ID', %dis },
    'vendor_qual_id'    => { label => 'Vendor qualification ID', %dis },
    'vendor_order_type' => {
                              label => 'Vendor order type',
                              disable_inventory => 1
                           }, # should be a select?
    'vendor_order_status' => {
                              label => 'Vendor order status',
                              disable_inventory => 1
                             }, # should also be a select?
    'endpoint_ip_addr'  => {
                              label => 'Endpoint IP address',
                           },
    'endpoint_mac_addr' => {
                              label => 'Endpoint MAC address',
                              type => 'input-mac_addr',
                              disable_inventory => 1,
                           },
  );
  return {
    'name'              => 'Circuit',
    'name_plural'       => 'Circuits',
    'longname_plural'   => 'Voice and data circuit services',
    'display_weight'    => 72,
    'cancel_weight'     => 85, # after svc_phone
    'fields'            => \%fields,
  };
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid service.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $mac_addr = uc($self->get('endpoint_mac_addr'));
  $mac_addr =~ s/[\W_]//g;
  $self->set('endpoint_mac_addr', $mac_addr);

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_number('typenum')
    || $self->ut_number('providernum')
    || $self->ut_text('circuit_id')
    || $self->ut_numbern('desired_due_date')
    || $self->ut_numbern('due_date')
    || $self->ut_textn('vendor_order_id')
    || $self->ut_textn('vendor_qual_id')
    || $self->ut_textn('vendor_order_type')
    || $self->ut_textn('vendor_order_status')
    || $self->ut_ipn('endpoint_ip_addr')
    || $self->ut_textn('endpoint_mac_addr')
  ;

  # no canonical values yet for vendor_order_status or _type

  return $error if $error;

  $self->SUPER::check;
}

=item label

Returns the circuit ID.

=cut

sub label {
  my $self = shift;
  $self->get('circuit_id');
}

=back

=head1 SEE ALSO

L<FS::Record>

=cut

1;

