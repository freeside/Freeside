package FS::cust_note_class;

use strict;
use base qw( FS::class_Common );
use FS::cust_main_note;

=head1 NAME

FS::cust_note_class - Object methods for cust_note_class records

=head1 SYNOPSIS

  use FS::cust_note_class;

  $record = new FS::cust_note_class \%hash;
  $record = new FS::cust_note_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_note_class object represents a customer note class. Every customer
note (see L<FS::cust_main_note) has, optionally, a note class. This class 
inherits from FS::class_Common.  The following fields are currently supported:

=over 4

=item classnum

primary key

=item classname

classname

=item disabled

disabled


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new customer note class.  To add the note class to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_note_class'; }
sub _target_table { 'cust_main_note'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid note class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main_note>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

