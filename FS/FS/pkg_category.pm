package FS::pkg_category;
use base qw( FS::category_Common );

use strict;
use vars qw( @ISA $me $DEBUG );
use FS::Record qw( qsearch qsearchs );
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

=item ticketing_queueid

Ticketing Queue

=item condense

Condense flag for invoice display, empty or 'Y'


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

=cut

sub check {
  my $self = shift;

  $self->ut_enum('condense', [ '', 'Y' ])
    || $self->ut_snumbern('ticketing_queueid')
    || $self->SUPER::check;
}

=item ticketing_queue

Returns the queue name corresponding with the id from the I<ticketing_queueid>
field, or the empty string.

=cut

sub ticketing_queue {
  my $self = shift;
  return 'Agent-specific queue' if $self->ticketing_queueid == -1;
  return '' unless $self->ticketing_queueid;
  FS::TicketSystem->queue($self->ticketing_queueid);
}

# _ upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

sub _upgrade_data {
  my ($class, %opts) = @_;

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

  # create default category for package fees
  my $tax_category_name = 'Taxes, Surcharges, and Fees';
  my $tax_category = qsearchs('pkg_category', 
    { categoryname => $tax_category_name }
  );
  if (!$tax_category) {
    $tax_category = FS::pkg_category->new({
        categoryname => $tax_category_name,
        weight       => 1000, # doesn't really matter
    });
    my $error = $tax_category->insert;
    die "error creating tax category: $error\n" if $error;
  }

  my $fee_class_name = 'Fees'; # does not appear on invoice
  my $fee_class = qsearchs('pkg_class', { classname => $fee_class_name });
  if (!$fee_class) {
    $fee_class = FS::pkg_class->new({
        classname   => $fee_class_name,
        categorynum => $tax_category->categorynum,
    });
    my $error = $fee_class->insert;
    die "error creating fee class: $error\n" if $error;
  }

  # assign it to all fee defs that don't otherwise have a class
  foreach my $part_fee (qsearch('part_fee', { classnum => '' })) {
    $part_fee->set('classnum', $fee_class->classnum);
    my $error = $part_fee->replace;
    die "error assigning default class to fee def#".$part_fee->feepart .
      ":$error\n" if $error;
  }

  '';
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::category_Common>, L<FS::Record>

=cut

1;

