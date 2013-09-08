package FS::svc_alarm;

use strict;
use base qw( FS::svc_Common );
use FS::Record; # qw( qsearch qsearchs );

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

=item alarm_system - Alarm System

=item alarm_type = Alarm Type

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
  {
    'name'           => 'Alarm service',
    'sorts'          => 'acctnum',
    'display_weight' => 80,
    'cancel_weight'  => 85,
    'fields' => {
      'svcnum'    => { label => 'Service' },
      'alarm_system'   => { label => 'Alarm System', %opts },
      'alarm_type'   => { label => 'Alarm Type', %opts },
      'acctnum'   => { label => 'Account #', %opts },
      '_password' => { label => 'Password', %opts },
      'location'  => { label => 'Location', %opts },
    },
  };
}

sub label {
  my $self = shift;
  $self->acctnum;
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

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid service.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref $x;

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_text('acctnum')
    || $self->ut_numbern('installdate')
    || $self->ut_anything('note')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>, L<FS::svc_Common>, schema.html from the base documentation.

=cut

1;
  
