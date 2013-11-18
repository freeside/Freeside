package FS::svc_cable;
use base qw( FS::svc_MAC_Mixin
             FS::svc_Common
           ); #FS::device_Common

use strict;
use Tie::IxHash;
use FS::Record qw( qsearchs ); # qw( qsearch qsearchs );
use FS::cable_provider;
use FS::cable_model;

=head1 NAME

FS::svc_cable - Object methods for svc_cable records

=head1 SYNOPSIS

  use FS::svc_cable;

  $record = new FS::svc_cable \%hash;
  $record = new FS::svc_cable { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_cable object represents a cable subscriber.  FS::svc_cable inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item svcnum

primary key

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_cable'; }

sub table_dupcheck_fields { ( 'mac_addr' ); }

sub search_sql {
  my( $class, $string ) = @_;
  if ( $string =~ /^([A-F0-9]{12})$/i ) {
    $class->search_sql_field('mac_addr', uc($string));
  } elsif ( $string =~ /^(([A-F0-9]{2}:){5}([A-F0-9]{2}))$/i ) {
    $string =~ s/://g;
    $class->search_sql_field('mac_addr', uc($string) );
  } elsif ( $string =~ /^(\w+)$/ ) {
    $class->search_sql_field('serialnum', $1);
  } else {
    '1 = 0'; #false
  }
}

sub table_info {

  tie my %fields, 'Tie::IxHash',
    'svcnum'      => 'Service',
    'providernum' => { label             => 'Provider',
                       type              => 'select-cable_provider',
                       disable_inventory => 1,
                       disable_select    => 1,
                       value_callback    => sub {
                                              my $svc = shift;
                                              my $p = $svc->cable_provider;
                                              $p ? $p->provider : '';
                                            },
                     },
    'ordernum'    => 'Order number', #XXX "Circuit ID/Order number"
    'modelnum'    => { label             => 'Model',
                       type              => 'select-cable_model',
                       disable_inventory => 1,
                       disable_select    => 1,
                       value_callback    => sub {
                                              my $svc = shift;
                                              $svc->cable_model->model_name;
                                            },
                     },
    'serialnum'   => 'Serial number',
    'mac_addr'    => { label          => 'MAC address',
                       type           => 'input-mac_addr',
                       value_callback => sub {
                                           my $svc = shift;
                                           join(':', $svc->mac_addr =~ /../g);
                                         },
                     },
  ;

  {
    'name'            => 'Cable Subscriber',
    #'name_plural'     => '', #optional,
    #'longname_plural' => '', #optional
    'fields'          => \%fields,
    'sorts'           => [ 'svcnum', 'serialnum', 'mac_addr', ],
    'display_weight'  => 54,
    'cancel_weight'   => 70, #?  no deps, so
  };
}

=item label

Returns the MAC address and serial number.

=cut

sub label {
  my $self = shift;
  my @label = ();
  push @label, 'MAC:'. $self->mac_addr_pretty
    if $self->mac_addr;
  push @label, 'Serial#:'. $self->serialnum
    if $self->serialnum;
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

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
       $self->ut_numbern('svcnum')
    || $self->ut_foreign_keyn('providernum', 'cable_provider', 'providernum')
    || $self->ut_alphan('ordernum')
    || $self->ut_foreign_key('modelnum', 'cable_model', 'modelnum')
    || $self->ut_alpha('serialnum')
    || $self->ut_mac_addr('mac_addr')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item cable_provider

Returns the cable_provider object for this record.

=cut

sub cable_provider {
  my $self = shift;
  qsearchs('cable_provider', { 'providernum'=>$self->providernum } );
}

=item cable_model

Returns the cable_model object for this record.

=cut

sub cable_model {
  my $self = shift;
  qsearchs('cable_model', { 'modelnum'=>$self->modelnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

