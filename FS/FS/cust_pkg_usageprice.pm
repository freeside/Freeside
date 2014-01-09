package FS::cust_pkg_usageprice;
use base qw( FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cust_pkg_usageprice - Object methods for cust_pkg_usageprice records

=head1 SYNOPSIS

  use FS::cust_pkg_usageprice;

  $record = new FS::cust_pkg_usageprice \%hash;
  $record = new FS::cust_pkg_usageprice { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pkg_usageprice object represents an specific customer package usage
pricing add-on.  FS::cust_pkg_usageprice inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item usagepricenum

primary key

=item pkgnum

pkgnum

=item usagepricepart

usagepricepart

=item quantity

quantity


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_pkg_usageprice'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('usagepricenum')
    || $self->ut_number('pkgnum')
    || $self->ut_number('usagepricepart')
    || $self->ut_number('quantity')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

