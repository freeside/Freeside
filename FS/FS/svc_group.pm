package FS::svc_group;
use base qw( FS::svc_Common );

use strict;
#use FS::Record qw( qsearch qsearchs );
#use FS::cust_svc;

=head1 NAME

FS::svc_group - Object methods for svc_group records

=head1 SYNOPSIS

  use FS::svc_group;

  $record = new FS::svc_group \%hash;
  $record = new FS::svc_group { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_group object represents a group.  FS::svc_group inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item max_accounts - Maximum number of group members

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new group.  To add the group to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_group'; }

sub table_info {
  {
    'name' => 'Group',
    'name_plural' => 'Groups', #optional,
    'longname_plural' => 'Groups', #optional
    'sorts' => 'svcnum', # optional sort field (or arrayref of sort fields, main first)
    'display_weight' => 100,
    'cancel_weight'  => 100,
    'fields' => {
      'svcnum'       => { label => 'Service' },
      'max_accounts' => { 
                           'label'     => 'Maximum number of accounts',
			   'type'      => 'text',
			   'disable_inventory' => 1,
			 },

    },
  };
}

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

#if we only have a quantity, then there's nothing to search on
#sub search_sql {
#  my($class, $string) = @_;
#  $class->search_sql_field('somefield', $string);
#}


=item label

Returns a meaningful identifier for this group

=cut

sub label {
  my $self = shift;
  $self->svcnum; #i guess?
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

=cut

#sub insert {
#  my $self = shift;
#  my $error;
#
#  $error = $self->SUPER::insert;
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

Checks all fields to make sure this is a valid group.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  my $error =  $self->ut_numbern('svcnum')
            || $self->ut_number('max_accounts');
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

