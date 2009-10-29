package FS::pkg_category;

use strict;
use base qw( FS::category_Common );
use vars qw( @ISA $me $DEBUG );
use FS::Record qw( qsearch dbh );
use FS::pkg_class;
use FS::part_pkg;

$DEBUG = 0;
$me = '[FS::pkg_category]';

=head1 NAME

FS::pkg_category - Object methods for pkg_category records

=head1 SYNOPSIS

  use FS::pkg_category;

  $record = new FS::pkg_category \%hash;
  $record = new FS::pkg_category { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::pkg_category object represents an package category.  Every package class
(see L<FS::pkg_class>) has, optionally, a package category. FS::pkg_category
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item categorynum

primary key (assigned automatically for new package categoryes)

=item categoryname

Text name of this package category

=item weight

Weight

=item disabled

Disabled flag, empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new package category.  To add the package category to the database,
see L<"insert">.

=cut

sub table { 'pkg_category'; }

=item insert

Adds this package category to the database.  If there is an error, returns the
error, otherwise returns false.

=item delete

Deletes this package category from the database.  Only package categoryes with
no associated package definitions can be deleted.  If there is an error,
returns the error, otherwise returns false.

=item replace [ OLD_RECORD ]

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid package category.  If there is an
error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

# _ upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.
#
#

sub _upgrade_data {
  my ($class, %opts) = @_;
  my $dbh = dbh;

  warn "$me upgrading $class\n" if $DEBUG;

  my @pkg_category =
    qsearch('pkg_category', { weight => { op => '!=', value => '' } } );

  unless( scalar(@pkg_category) ) {
    my @pkg_category = qsearch('pkg_category', {} );
    my $weight = 0;
    foreach ( sort { $a->description cmp $b->description } @pkg_category ) {
      $_->weight($weight);
      my $error = $_->replace;
      die "error setting pkg_category weight: $error\n" if $error;
      $weight += 10;
    }
  }
  '';
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::category_Common>, L<FS::Record>

=cut

1;

