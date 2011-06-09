package FS::rate_prefix;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );
use FS::rate_region;

@ISA = qw(FS::Record);

=head1 NAME

FS::rate_prefix - Object methods for rate_prefix records

=head1 SYNOPSIS

  use FS::rate_prefix;

  $record = new FS::rate_prefix \%hash;
  $record = new FS::rate_prefix { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::rate_prefix object represents an call rating prefix.  FS::rate_prefix
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item prefixnum - primary key

=item regionnum - call ration region (see L<FS::rate_region>)

=item countrycode

=item npa

=item nxx

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new prefix.  To add the prefix to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'rate_prefix'; }

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

Checks all fields to make sure this is a valid prefix.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error =
       $self->ut_numbern('prefixnum')
    || $self->ut_foreign_key('regionnum', 'rate_region', 'regionnum' )
    || $self->ut_number('countrycode')
    || $self->ut_numbern('npa')
    || $self->ut_numbern('nxx')
    || $self->ut_foreign_keyn('latanum', 'lata', 'latanum')
    || $self->ut_textn('state')
    || $self->ut_textn('ocn')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item rate_region

Returns the rate region (see L<FS::rate_region>) for this prefix.

=cut

sub rate_region {
  my $self = shift;
  qsearchs('rate_region', { 'regionnum' => $self->regionnum } );
}

=back

=head1 CLASS METHODS

=over 4

=item all_countrycodes

Returns a list of all countrycodes listed in rate_prefix

=cut

sub all_countrycodes { 
  #my $class = shift;
  my $sql =
    "SELECT DISTINCT(countrycode) FROM rate_prefix ORDER BY countrycode";
  my $sth = dbh->prepare($sql) or die  dbh->errstr;
  $sth->execute                or die $sth->errstr;
  map $_->[0], @{ $sth->fetchall_arrayref };
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::rate_region>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

