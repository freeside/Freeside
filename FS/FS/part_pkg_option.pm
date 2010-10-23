package FS::part_pkg_option;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbh );
use FS::part_pkg;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_pkg_option - Object methods for part_pkg_option records

=head1 SYNOPSIS

  use FS::part_pkg_option;

  $record = new FS::part_pkg_option \%hash;
  $record = new FS::part_pkg_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_option object represents an package definition option.
FS::part_pkg_option inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item optionnum - primary key

=item pkgpart - package definition (see L<FS::part_pkg>)

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

sub table { 'part_pkg_option'; }

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
    || $self->ut_foreign_key('pkgpart', 'part_pkg', 'pkgpart')
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

  my $sql = "UPDATE part_pkg_option SET optionname = 'recur_fee'".
            " WHERE optionname = 'recur_flat'";
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute or die $sth->errstr;

  $sql = "UPDATE part_pkg_option SET optionname = 'recur_method',".
            "optionvalue = 'prorate'  WHERE optionname = 'enable_prorate'";
  $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute or die $sth->errstr;

  $sql = "UPDATE part_pkg_option SET optionvalue = NULL WHERE ".
            "optionname = 'contract_end_months' AND optionvalue = '(none)'";
  $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute or die $sth->errstr;
  '';

}

=head1 BUGS

Possibly.

=head1 SEE ALSO

L<FS::part_pkg>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

