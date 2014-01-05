package FS::svc_conferencing;
use base qw( FS::svc_Common );

use strict;
use Tie::IxHash;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::svc_conferencing - Object methods for svc_conferencing records

=head1 SYNOPSIS

  use FS::svc_conferencing;

  $record = new FS::svc_conferencing \%hash;
  $record = new FS::svc_conferencing { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_conferencing object represents a conferencing service.
FS::svc_conferencing inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item svcnum

primary key

=item conf_id

conf_id

=item conf_name

conf_name

=item conf_password

conf_password

=item access_code

access_code

=item duration

duration

=item participants

participants

=item conftypenum

conftypenum

=item confqualitynum

confqualitynum

=item opt_recording

opt_recording

=item opt_sip

opt_sip

=item opt_phone

opt_phone


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_conferencing'; }

sub table_info {

  my %opts = ( 'type' => 'text', 
               'disable_select' => 1,
               'disable_inventory' => 1,
             );

  tie my %fields, 'Tie::IxHash',
    'svcnum'         => { label => 'Service' },
    'conf_id'        => { label => 'Conference ID', %opts, },
    'conf_name'      => { label     => 'Conference Name',
                          size      => 31,
                          maxlength => 30,
                          %opts,
                        },
    'conf_password'  => { label     => 'Password',
                          size      => 31,
                          maxlength => 30,
                          %opts,
                        },
    'access_code'    => { label     => 'Access code' ,
                          size      => 17,
                          maxlength => 16,
                          %opts,
                        },
    'duration'       => { label => 'Duration',
                          type  => 'duration',
                          disable_select    => 1,
                          disable_inventory => 1,
                          value_callback    => sub {
                            my $min = shift->duration;
                            int($min/60)."h".
                            sprintf("%02d",$min%60)."m";
                          },
                        },
    'participants'   => { label => 'Num. participants', size=>5, %opts },
    'conftypenum'    => { label             => 'Conference type',
                          type              => 'select-conferencing_type',
                          disable_select    => 1,
                          disable_inventory => 1,
                          value_callback    => sub {
                            shift->conferencing_type->typename;
                          },
                        },
    'confqualitynum' => { label             => 'Quality',
                          type              => 'select-conferencing_quality',
                          disable_select    => 1,
                          disable_inventory => 1,
                          value_callback    => sub {
                            shift->conferencing_quality->qualityname;
                          },
                        },
    'opt_recording'  => { label             => 'Recording',
                          type              => 'checkbox',
                          value             => 'Y',
                          disable_select    => 1,
                          disable_inventory => 1,
                        },
    'opt_sip'        => { label             => 'SIP participation',
                          type              => 'checkbox',
                          value             => 'Y',
                          disable_select    => 1,
                          disable_inventory => 1,
                        },
    'opt_phone'      => { label             => 'Phone participation',
                          type              => 'checkbox',
                          value             => 'Y',
                          disable_select    => 1,
                          disable_inventory => 1,
                        },
  ;

  {
    'name'                => 'Conferencing', # service',
    #'name_plural'     => '', #optional,
    #'longname_plural' => '', #optional
    'fields'              => \%fields,
    'addl_process_fields' => [ 'duration_units' ],
    'sorts'               => [ 'conf_id', 'conf_name' ],
    'display_weight'      => 57,
    'cancel_weight'       => 70, #?  no deps, so
  };

}

sub label {
  my $self = shift;
  $self->conf_id.': '. $self->conf_name;
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

  if ( $self->duration_units && $self->duration_units > 1 ) {
    $self->duration( int( ($self->duration * $self->duration_units) + .5) );
   
    $self->duration_units(1);
  }

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_numbern('conf_id')
    || $self->ut_text('conf_name')
    || $self->ut_text('conf_password')
    || $self->ut_text('access_code')
    || $self->ut_number('duration')
    || $self->ut_number('participants')
    || $self->ut_number('conftypenum')
    || $self->ut_number('confqualitynum')
    || $self->ut_enum('opt_recording', [ '', 'Y' ])
    || $self->ut_enum('opt_sip',       [ '', 'Y' ])
    || $self->ut_enum('opt_phone',     [ '', 'Y' ])
  ;
  return $error if $error;

  return 'Meeting name must be at least 4 characters'
    unless length($self->conf_name) >= 4;
  return 'Password must be at least 4 characters'
    unless length($self->conf_password) >= 4;
  return 'Access code must be at least 4 digits'
    unless length($self->access_code) >= 4;


  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

