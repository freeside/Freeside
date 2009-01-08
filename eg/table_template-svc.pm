package FS::svc_table;

use strict;
use base qw( FS::svc_Common );
#use FS::Record qw( qsearch qsearchs );
use FS::cust_svc;

=head1 NAME

FS::table_name - Object methods for table_name records

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

An FS::table_name object represents an example.  FS::table_name inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item field - description

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'table_name'; }

sub table_info {
  {
    'name' => 'Example',
    'name_plural' => 'Example services', #optional,
    'longname_plural' => 'Example services', #optional
    'sorts' => 'svcnum', # optional sort field (or arrayref of sort fields, main first)
    'display_weight' => 100,
    'cancel_weight'  => 100,
    'fields' => {
      'field'         => 'Description',
      'another_field' => { 
                           'label'     => 'Description',
			   'def_label' => 'Description for service definitions',
			   'type'      => 'text',
			   'disable_default'   => 1, #disable switches
			   'disable_fixed'     => 1, #
			   'disable_inventory' => 1, #
			 },
      'foreign_key'   => { 
                           'label'        => 'Description',
			   'def_label'    => 'Description for service defs',
			   'type'         => 'select',
			   'select_table' => 'foreign_table',
			   'select_key'   => 'key_field_in_table',
			   'select_label' => 'label_field_in_table',
			 },

    },
  };
}

=item search_sql STRING

Class method which returns an SQL fragment to search for the given string.

=cut

#or something more complicated if necessary
sub search_sql {
  my($class, $string) = @_;
  $class->search_sql_field('search_field', $string);
}

=item label

Returns a meaningful identifier for this example

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

Checks all fields to make sure this is a valid example.  If there is
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

The author forgot to customize this manpage.

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

