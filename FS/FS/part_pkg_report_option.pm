package FS::part_pkg_report_option;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs dbh );

=head1 NAME

FS::part_pkg_report_option - Object methods for part_pkg_report_option records

=head1 SYNOPSIS

  use FS::part_pkg_report_option;

  $record = new FS::part_pkg_report_option \%hash;
  $record = new FS::part_pkg_report_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_report_option object represents a package definition optional
reporting classification.  FS::part_pkg_report_option inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item num

primary key

=item name

name - The name associated with the reporting option

=item disabled

disabled - set to 'Y' to prevent addition to new packages


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new report option.  To add the option to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'part_pkg_report_option'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

sub delete {
  return "Can't delete part_pkg_report_option records!";
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('num')
    || $self->ut_text('name')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 CLASS METHODS

=over 4

=item subsets OPTIONNUM, ...

Given a list of report_option numbers, determines all combinations of those
numbers that exist on actual package definitions.  For each such combination,
returns an arrayref of report_option numbers, followed by an arrayref of
corresponding report class names.  This is used for a search optimization.

=cut

# probably doesn't belong here, but there's not a better place for it
# and optimizations are, by nature, hackish

sub subsets {
  my ($self, @nums) = @_;
  my @optionnames = map { "'report_option_$_'" } @nums;
  my $where = "WHERE optionname IN(".join(',',@optionnames).")"
    if @nums;
  my $subselect =
    "SELECT pkgpart, replace(optionname, 'report_option_', '')::int AS num ".
    "FROM part_pkg_option $where ".
    "ORDER BY pkgpart, num";
  my $select =
    "SELECT DISTINCT array_to_string(array_agg(num), ','), ".
    "array_to_string(array_agg(name), ',') ".
    "FROM ($subselect) AS x JOIN part_pkg_report_option USING (num) ".
    "GROUP BY pkgpart";
  my $dbh = dbh;
  my $sth = $dbh->prepare($select)
    or die $dbh->errstr; # seriously, this should never happen
  $sth->execute
    or die $sth->errstr;
  # return the first (only) column
  map { [ split(',',$_->[0]) ],
        [ split(',',$_->[1]) ] } @{ $sth->fetchall_arrayref };
}

=back

=head1 BUGS

Overlaps somewhat with pkg_class and pkg_category

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

