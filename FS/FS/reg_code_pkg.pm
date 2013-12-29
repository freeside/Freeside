package FS::reg_code_pkg;
use base qw(FS::Record);

use strict;

=head1 NAME

FS::reg_code_pkg - Class linking registration codes (see L<FS::reg_code>) with package definitions (see L<FS::part_pkg>)

=head1 SYNOPSIS

  use FS::reg_code_pkg;

  $record = new FS::reg_code_pkg \%hash;
  $record = new FS::reg_code_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::reg_code_pkg object links a registration code to a package definition.
FS::table_name inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item codepkgnum - primary key

=item codenum - registration code (see L<FS::reg_code>)

=item pkgpart - package definition (see L<FS::part_pkg>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new registration code.  To add the registration code to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'reg_code_pkg'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
       $self->ut_numbern('codepkgnum')
    || $self->ut_foreign_key('codenum', 'reg_code', 'codenum')
    || $self->ut_foreign_key('pkgpart', 'part_pkg', 'pkgpart')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_pkg

Returns the package definition (see L<FS::part_pkg>)

=back

=head1 BUGS

Feeping creaturitis.

=head1 SEE ALSO

L<FS::reg_code_pkg>, L<FS::Record>, schema.html from the base documentation.

=cut

1;


