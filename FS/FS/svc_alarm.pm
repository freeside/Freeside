package FS::svc_alarm;
use base qw( FS::svc_Common );

use strict;
use Tie::IxHash;
use FS::alarm_system;
use FS::alarm_type;
use FS::alarm_station;

=head1 NAME

FS::svc_alarm - Object methods for svc_alarm records

=head1 SYNOPSIS

  use FS::svc_alarm;

  $record = new FS::svc_alarm \%hash;
  $record = new FS::svc_alarm { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_alarm object represents an alarm service.  FS::svc_alarm inherits
from FS::svc_Common.

The following fields are currently supported:

=over 4

=item svcnum - Primary key

=item alarmsystemnum - Alarm System Vendor (see L<FS::alarm_system>)

=item alarmtypenum - Alarm System Type (inputs/outputs) (see L<FS::alarm_type>)

=item alarmstationnum - Alarm central station (see L<FS::alarm_station>)

=item acctnum - Account number

=item _password - Password

=item location - Location on property

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new svc_dish object.

=cut

sub table { 'svc_alarm'; }

sub table_info {
  my %opts = ( 'type' => 'text', 
               #'disable_select' => 1,
               'disable_inventory' => 1,
             );

  tie my %fields, 'Tie::IxHash',
    'svcnum'    => { label => 'Service' },
    'acctnum'         => { label => 'Account #', %opts },
    '_password'       => { label => 'Password' , %opts },
    'location'        => { label => 'Location',  %opts },
    'cs_receiver'     => { label => 'CS Reciever #'},
    'cs_phonenum'     => { label => 'CS Phone #' },
    'serialnum'       => { label => 'Alarm Serial #' },
    'alarmsystemnum'  => { label => 'Alarm System Vendor',
                           type  => 'select-alarm_system',
                           disable_inventory => 1,
                           value_callback    => sub {
                             shift->alarm_system->systemname
                           },
                         },
    'alarmtypenum'    => { label => 'Alarm System Type',
                           type  => 'select-alarm_type',
                           disable_inventory => 1,
                           value_callback    => sub {
                             shift->alarm_type->typename
                           },
                         },
    'alarmstationnum' => { label => 'Alarm Central Station',
                           type  => 'select-alarm_station',
                           disable_inventory => 1,
                           value_callback    => sub {
                             shift->alarm_station->stationname
                           },
                         },
  ;

  {
    'name'                => 'Alarm service',
    'sorts'               => 'acctnum',
    'display_weight'      => 80,
    'cancel_weight'       => 85,
    'fields'              => \%fields,
    'addl_process_fields' => [qw( alarmsystemnum_systemname
                                  alarmtypenum_inputs alarmtypenum_outputs
                                  alarmstationnum_stationname
                             )],
  };
}

sub label {
  my $self = shift;
  $self->acctnum . '@'. $self->alarm_station->stationname. #?
    ' ('. $self->alarm_system->systemname. ' '. $self->alarm_type->typename. ')'
  ;
}

sub search_sql {
  my($class, $string) = @_;
  $class->search_sql_field('acctnum', $string);
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub preinsert_hook_first  { shift->_inline_add(@_); }
sub prereplace_hook_first { shift->_inline_add(@_); }

sub _inline_add {
  my $self = shift;

  my $agentnum = $self->cust_svc->cust_pkg->cust_main->agentnum;

  if ( $self->alarmsystemnum == -1 ) {
    my $alarm_system = new FS::alarm_system {
      'agentnum'   => $agentnum,
      'systemname' => $self->alarmsystemnum_systemname,
    };
    my $error = $alarm_system->insert;
    return $error if $error;
    $self->alarmsystemnum($alarm_system->alarmsystemnum);
  }

  if ( $self->alarmtypenum == -1 ) {
    my $alarm_type = new FS::alarm_type {
      'agentnum' => $agentnum,
      'inputs'   => $self->alarmtypenum_inputs,
      'outputs'  => $self->alarmtypenum_outputs,
    };
    my $error = $alarm_type->insert;
    return $error if $error;
    $self->alarmtypenum($alarm_type->alarmtypenum);
  }

  if ( $self->alarmstationnum == -1 ) {
    my $alarm_station = new FS::alarm_station {
      'agentnum'    => $agentnum,
      'stationname' => $self->alarmstationnum_stationname,
    };
    my $error = $alarm_station->insert;
    return $error if $error;
    $self->alarmstationnum($alarm_station->alarmstationnum)
  }

  '';
}

=item check

Checks all fields to make sure this is a valid service.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref $x;

  my $iso3166 = $self->cust_main->ship_location->country();

  my $error =
    $self->ut_numbern('svcnum')
    || $self->ut_text('acctnum')
    || $self->ut_alphan('_password')
    || $self->ut_textn('location')
    || $self->ut_numbern('cs_receiver')
    || $self->ut_phonen('cs_phonenum', $iso3166)
    || $self->ut_alphan('serialnum')
    || $self->ut_foreign_key('alarmsystemnum',  'alarm_system',  'systemnum')
    || $self->ut_foreign_key('alarmtypenum',    'alarm_type',    'typenum')
    || $self->ut_foreign_key('alarmstationnum', 'alarm_station', 'stationnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>, L<FS::svc_Common>, schema.html from the base documentation.

=cut

1;
  
