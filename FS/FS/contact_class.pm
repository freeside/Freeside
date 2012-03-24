package FS::contact_class;
use base qw( FS::class_Common );

use strict;
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::contact_class - Object methods for contact_class records

=head1 SYNOPSIS

  use FS::contact_class;

  $record = new FS::contact_class \%hash;
  $record = new FS::contact_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::contact_class object represents a contact class.  FS::contact_class
inherits from FS::class_Common.  The following fields are currently supported:

=over 4

=item classnum

primary key

=item classname

Class name

=item disabled

Disabled flag

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'contact_class'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.
=item check

Checks all fields to make sure this is a valid class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=back

=head1 BUGS

The author forgot to customize this manpage.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

