package FS::part_pkg_link;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::part_pkg;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_pkg_link - Object methods for part_pkg_link records

=head1 SYNOPSIS

  use FS::part_pkg_link;

  $record = new FS::part_pkg_link \%hash;
  $record = new FS::part_pkg_link { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_link object represents an link from one package definition to
another.  FS::part_pkg_link inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item pkglinknum

primary key

=item src_pkgpart

Source package (see L<FS::part_pkg>)

=item dst_pkgpart

Destination package (see L<FS::part_pkg>)

=item link_type

Link type - currently, "bill" (source package bills a line item from target
package), or "svc" (source package includes services from target package).

=item hidden

Flag indicating that this subpackage should be felt, but not seen as an invoice
line item when set to 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new link.  To add the link to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_pkg_link'; }

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

Checks all fields to make sure this is a valid link.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('pkglinknum')
    || $self->ut_foreign_key('src_pkgpart', 'part_pkg', 'pkgpart')
    || $self->ut_foreign_key('dst_pkgpart', 'part_pkg', 'pkgpart')
    || $self->ut_enum('link_type', [ 'bill', 'svc' ] )
    || $self->ut_enum('hidden', [ '', 'Y' ] )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item src_pkg

Returns the source part_pkg object (see L<FS::part_pkg>).

=cut

sub src_pkg {
  my $self = shift;
  qsearchs('part_pkg', { 'pkgpart' => $self->src_pkgpart } );
}

=item dst_pkg

Returns the source part_pkg object (see L<FS::part_pkg>).

=cut

sub dst_pkg {
  my $self = shift;
  qsearchs('part_pkg', { 'pkgpart' => $self->dst_pkgpart } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

