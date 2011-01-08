package FS::svc_port;

use strict;
use base qw( FS::svc_Common );
#use FS::Record qw( qsearch qsearchs );
use FS::cust_svc;

=head1 NAME

FS::svc_port - Object methods for svc_port records

=head1 SYNOPSIS

  use FS::svc_port;

  $record = new FS::svc_port \%hash;
  $record = new FS::svc_port { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_port object represents a router port.  FS::table_name inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item svcnum - 

=item serviceid - Torrus serviceid (in srvexport and reportfields tables)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new port.  To add the port to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_port'; }

sub table_info {
  {
    'name' => 'Port',
    #'name_plural' => 'Ports', #optional,
    #'longname_plural' => 'Ports', #optional
    'sorts' => [ 'svcnum', 'serviceid' ], # optional sort field (or arrayref of sort fields, main first)
    'display_weight' => 75,
    'cancel_weight'  => 10,
    'fields' => {
      'serviceid'         => 'Torrus serviceid',
    },
  };
}

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

#or something more complicated if necessary
sub search_sql {
  my($class, $string) = @_;
  $class->search_sql_field('serviceid', $string);
}

=item label

Returns a meaningful identifier for this port

=cut

sub label {
  my $self = shift;
  $self->serviceid; #or something more complicated if necessary
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

=cut

sub insert {
  my $self = shift;
  my $error;

  $error = $self->SUPER::insert;
  return $error if $error;

  '';
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;
  my $error;

  $error = $self->SUPER::delete;
  return $error if $error;

  '';
}


=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );
  my $error;

  $error = $new->SUPER::replace($old);
  return $error if $error;

  '';
}

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid port.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  my $error = $self->ut_textn('serviceid'); #too lenient?
  return $error if $error;

  $self->SUPER::check;
}

=item

Returns a PNG graph for this port.

XXX Options

=cut

sub graph_png {
  my $self = shift;
  my $serviceid = $self->serviceid;


}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

