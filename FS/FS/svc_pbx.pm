package FS::svc_pbx;

use strict;
use base qw( FS::svc_External_Common );
#use FS::Record qw( qsearch qsearchs );
use FS::cust_svc;

=head1 NAME

FS::svc_pbx - Object methods for svc_pbx records

=head1 SYNOPSIS

  use FS::svc_pbx;

  $record = new FS::svc_pbx \%hash;
  $record = new FS::svc_pbx { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_pbx object represents a PBX tenant.  FS::svc_pbx inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item svcnum

Primary key (assigned automatcially for new accounts)

=item id

(Unique?) number of external record

=item title

PBX name

=item max_extensions

Maximum number of extensions

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new PBX tenant.  To add the PBX tenant to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_pbx'; }

sub table_info {
  {
    'name' => 'PBX',
    'name_plural' => 'PBXs', #optional,
    'longname_plural' => 'PBXs', #optional
    'sorts' => 'svcnum', # optional sort field (or arrayref of sort fields, main first)
    'display_weight' => 70,
    'cancel_weight'  => 90,
    'fields' => {
      'id'    => 'Thirdlane ID',
      'title' => 'Description',
      'max_extensions' => 'Maximum number of User Extensions',
#      'field'         => 'Description',
#      'another_field' => { 
#                           'label'     => 'Description',
#			   'def_label' => 'Description for service definitions',
#			   'type'      => 'text',
#			   'disable_default'   => 1, #disable switches
#			   'disable_fixed'     => 1, #
#			   'disable_inventory' => 1, #
#			 },
#      'foreign_key'   => { 
#                           'label'        => 'Description',
#			   'def_label'    => 'Description for service defs',
#			   'type'         => 'select',
#			   'select_table' => 'foreign_table',
#			   'select_key'   => 'key_field_in_table',
#			   'select_label' => 'label_field_in_table',
#			 },

    },
  };
}

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

#XXX
#or something more complicated if necessary
#sub search_sql {
#  my($class, $string) = @_;
#  $class->search_sql_field('title', $string);
#}

=item label

Returns a meaningful identifier for this PBX tenant.

=cut

sub label {
  my $self = shift;
  $self->label_field; #or something more complicated if necessary
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

Checks all fields to make sure this is a valid PBX tenant.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;


  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

