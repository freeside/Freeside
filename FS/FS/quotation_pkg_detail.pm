package FS::quotation_pkg_detail;
use base qw(FS::Record);

use strict;

=head1 NAME

FS::quotation_pkg_detail - Object methods for quotation_pkg_detail records

=head1 SYNOPSIS

  use FS::quotation_pkg_detail;

  $record = new FS::quotation_pkg_detail \%hash;
  $record = new FS::quotation_pkg_detail { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::quotation_pkg_detail object represents additional customer package details
for a quotation.  FS::quotation_pkg_detail inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item detailnum

primary key

=item quotationpkgnum

for the relevant L<FS::quotation_pkg>

=item detail

detail text

=item copy_on_order

flag, indicates detail should be copied over when ordering

=cut

# 'format' field isn't used, there for TemplateItem_Mixin

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'quotation_pkg_detail'; }

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
    $self->ut_numbern('detailnum')
    || $self->ut_foreign_key('quotationpkgnum', 'quotation_pkg', 'quotationpkgnum')
    || $self->ut_text('detail')
    || $self->ut_flag('copy_on_order')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::quotation_pkg>, L<FS::Record>

=cut

1;

