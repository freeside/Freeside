package FS::cust_pkg_detail;

use strict;
use vars qw( @ISA );
use FS::Record; # qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::cust_pkg_detail - Object methods for cust_pkg_detail records

=head1 SYNOPSIS

  use FS::cust_pkg_detail;

  $record = new FS::cust_pkg_detail \%hash;
  $record = new FS::cust_pkg_detail { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pkg_detail object represents additional customer package details.
FS::cust_pkg_detail inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item pkgdetailnum

primary key

=item pkgnum

pkgnum (see L<FS::cust_pkg>)

=item detail

detail

=item detailtype

"I" for Invoice details or "C" for comments

=item weight

Optional display weight

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_pkg_detail'; }

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
    $self->ut_numbern('pkgdetailnum')
    || $self->ut_foreign_key('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_text('detail')
    || $self->ut_enum('detailtype', [ 'I', 'C' ] )
    || $self->ut_numbern('weight')
  ;
  return $error if $error;

  $self->weight(0) unless $self->weight;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_pkg>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

