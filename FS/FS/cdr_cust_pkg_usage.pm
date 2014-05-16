package FS::cdr_cust_pkg_usage;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cdr_cust_pkg_usage - Object methods for cdr_cust_pkg_usage records

=head1 SYNOPSIS

  use FS::cdr_cust_pkg_usage;

  $record = new FS::cdr_cust_pkg_usage \%hash;
  $record = new FS::cdr_cust_pkg_usage { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cdr_cust_pkg_usage object represents an allocation of included 
usage minutes to a call.  FS::cdr_cust_pkg_usage inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item cdrusagenum - primary key

=item acctid - foreign key to cdr.acctid

=item pkgusagenum - foreign key to cust_pkg_usage.pkgusagenum

=item minutes - the number of minutes allocated

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cdr_cust_pkg_usage'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('cdrusagenum')
    || $self->ut_foreign_key('acctid', 'cdr', 'acctid')
    || $self->ut_foreign_key('pkgusagenum', 'cust_pkg_usage', 'pkgusagenum')
    || $self->ut_float('minutes')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item cust_pkg_usage

Returns the L<FS::cust_pkg_usage> object that this usage allocation came from.

=item cdr

Returns the L<FS::cdr> object that the usage was applied to.

=cut

sub cust_pkg_usage {
  FS::cust_pkg_usage->by_key($_[0]->pkgusagenum);
}

sub cdr {
  FS::cdr->by_key($_[0]->acctid);
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

