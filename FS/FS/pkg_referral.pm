package FS::pkg_referral;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::pkg_referral - Object methods for pkg_referral records

=head1 SYNOPSIS

  use FS::pkg_referral;

  $record = new FS::pkg_referral \%hash;
  $record = new FS::pkg_referral { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::pkg_referral object represents the association of an advertising source
with a specific customer package (purchase).  FS::pkg_referral inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item pkgrefnum - primary key

=item pkgnum - Customer package.  See L<FS::cust_pkg>

=item refnum - Advertising source.  See L<FS::part_referral>

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'pkg_referral'; }

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
    $self->ut_numbern('pkgrefnum')
    || $self->ut_foreign_key('pkgnum', 'cust_pkg',      'pkgnum' )
    || $self->ut_foreign_key('refnum', 'part_referral', 'refnum' )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

Multiple pkg_referral records for a single package (configured off by default)
still seems weird.

=head1 SEE ALSO

L<FS::part_referral>, L<FS::cust_pkg>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

