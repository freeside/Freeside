package FS::pkg_svc_option;
use base qw(FS::Record);

use strict;
use FS::Record qw( dbh ); # qw( qsearch qsearchs dbh );
use FS::pkg_svc;

=head1 NAME

FS::pkg_svc_option - Object methods for pkg_svc_option records

=head1 SYNOPSIS

  use FS::pkg_svc_option;

  $record = new FS::pkg_svc_option \%hash;
  $record = new FS::pkg_svc_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::pkg_svc_option object represents an package definition option.
FS::pkg_svc_option inherits from FS::Record.  The following fields are
currently supported:

This is what we think my be the best way to model some of our custom options for specific constraints in a service, and still allow for multiples in a package (each with their own constraints)

=over 4

=item optionnum - primary key

=item pkgsvcnum - package definition (see L<FS::pkg_svc>)

=item optionname - option name

=item optionvalue - option value

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new package definition option.  To add the package definition option
to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'pkg_svc_option'; }

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

Checks all fields to make sure this is a valid package definition option.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('optionnum')
    || $self->ut_foreign_key('pkgsvcnum', 'pkg_svc', 'pkgsvcnum')
    || $self->ut_alpha('optionname')
    || $self->ut_anything('optionvalue')
  ;
  return $error if $error;

  #check options & values?

  $self->SUPER::check;
}

=back

=cut

#
# Used by FS::Upgrade to migrate to a new database.
#
#

sub _upgrade_data {  # class method
  my ($class, %opts) = @_;
}

=head1 BUGS

Possibly.

=head1 SEE ALSO

L<FS::pkg_svc>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

