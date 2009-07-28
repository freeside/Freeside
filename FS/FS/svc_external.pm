package FS::svc_external;

use strict;
use vars qw(@ISA);
use FS::Conf;
use FS::svc_External_Common;

@ISA = qw( FS::svc_External_Common );

=head1 NAME

FS::svc_external - Object methods for svc_external records

=head1 SYNOPSIS

  use FS::svc_external;

  $record = new FS::svc_external \%hash;
  $record = new FS::svc_external { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_external object represents a generic externally tracked service.
FS::svc_external inherits from FS::svc_External_Common (and FS::svc_Common).
The following fields are currently supported:

=over 4

=item svcnum - primary key

=item id - unique number of external record

=item title - for invoice line items

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new external service.  To add the external service to the database,
see L<"insert">.  

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table_info {
  {
    'name' => 'External service',
    'sorts' => 'id',
    'display_weight' => 90,
    'cancel_weight'  => 10,
    'fields' => {
      'id'    => { label => 'Unique number of external record',
                   type  => 'text',
                   disable_default => 1,
                   disable_fixed   => 1,
                 },
      'title' => { label => 'Printed on invoice line items',
                   type  => 'text',
                   disable_inventory => 1,
                 },
    },
  };
}

sub table { 'svc_external'; }

# oh!  this should be moved to svc_artera_turbo or something now
sub label {
  my $self = shift;
  my $conf = new FS::Conf;
  if (    $conf->exists('svc_external-display_type')
       && $conf->config('svc_external-display_type') eq 'artera_turbo' )
  {
    sprintf('%010d', $self->id). '-'.
      substr('0000000000'.uc($self->title), -10);
  } else {
    #$self->SUPER::label;
    return $self->id unless $self->title =~ /\S/;
    $self->id. ' - '. $self->title;
  }
}

=item insert [ , OPTION => VALUE ... ]

Adds this external service to the database.  If there is an error, returns the
error, otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

Currently available options are: I<depend_jobnum>

If I<depend_jobnum> is set (to a scalar jobnum or an array reference of
jobnums), all provisioning jobs will have a dependancy on the supplied
jobnum(s) (they will not run until the specific job(s) complete(s)).

=cut

#sub insert {
#  my $self = shift;
#  my $error;
#
#  $error = $self->SUPER::insert(@_);
#  return $error if $error;
#
#  '';
#}

=item delete

Delete this record from the database.

=cut

#sub delete {
#  my $self = shift;
#  my $error;
#
#  $error = $self->SUPER::delete;
#  return $error if $error;
#
#  '';
#}


=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

#sub replace {
#  my ( $new, $old ) = ( shift, shift );
#  my $error;
#
#  $error = $new->SUPER::replace($old);
#  return $error if $error;
#
#  '';
#}

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid external service.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

#sub check {
#  my $self = shift;
#  my $error;
#
#  $error = $self->SUPER::delete;
#  return $error if $error;
#
#  '';
#}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_External_Common>, L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>,
L<FS::part_svc>, L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

