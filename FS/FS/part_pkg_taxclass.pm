package FS::part_pkg_taxclass;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::part_pkg_taxclass - Object methods for part_pkg_taxclass records

=head1 SYNOPSIS

  use FS::part_pkg_taxclass;

  $record = new FS::part_pkg_taxclass \%hash;
  $record = new FS::part_pkg_taxclass { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_taxclass object represents a tax class.  FS::part_pkg_taxclass
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item taxclassnum

Primary key

=item taxclass

Tax class

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax class.  To add the tax class to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_pkg_taxclass'; }

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

Checks all fields to make sure this is a valid tax class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('serial')
    || $self->ut_number('taxclassnum')
    || $self->ut_text('taxclass')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

Other tables (cust_main_county, part_pkg, agent_payment_gateway) have a text
taxclass instead of a key to this table.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

