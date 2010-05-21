package FS::inventory_class;

use strict;
use vars qw( @ISA );
use FS::Record qw( dbh qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::inventory_class - Object methods for inventory_class records

=head1 SYNOPSIS

  use FS::inventory_class;

  $record = new FS::inventory_class \%hash;
  $record = new FS::inventory_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::inventory_class object represents a class of inventory, such as "DID 
numbers" or "physical equipment serials".  FS::inventory_class inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item classnum - primary key

=item classname - Name of this class


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new inventory class.  To add the class to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'inventory_class'; }

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

Checks all fields to make sure this is a valid inventory class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('classnum')
    || $self->ut_textn('classname')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item num_avail 

Returns the number of available (unused/unallocated) inventory items of this
class (see L<FS::inventory_item>).

=cut

sub num_avail {
  shift->num_sql('( svcnum IS NULL OR svcnum = 0 )');
}

sub num_sql {
  my( $self, $sql ) = @_;
  $sql = "AND $sql" if length($sql);

  my $agentnums_sql = $FS::CurrentUser::CurrentUser->agentnums_sql(
    'null'  => 1,
    'table' => 'inventory_item',
  );

  my $st = "SELECT COUNT(*) FROM inventory_item ".
           " WHERE classnum = ? AND $agentnums_sql $sql";
  my $sth = dbh->prepare($st)    or die  dbh->errstr. " preparing $st";
  $sth->execute($self->classnum) or die $sth->errstr. " executing $st";
  $sth->fetchrow_arrayref->[0];
}

=item num_used

Returns the number of used (allocated) inventory items of this class (see
L<FS::inventory_class>).

=cut

sub num_used {
  shift->num_sql("svcnum IS NOT NULL AND svcnum > 0 ");
}

=item num_total

Returns the total number of inventory items of this class (see
L<FS::inventory_class>).

=cut

sub num_total {
  shift->num_sql('');
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::inventory_item>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

