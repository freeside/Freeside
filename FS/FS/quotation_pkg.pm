package FS::quotation_pkg;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearchs ); #qsearch
use FS::part_pkg;
use FS::cust_location;

=head1 NAME

FS::quotation_pkg - Object methods for quotation_pkg records

=head1 SYNOPSIS

  use FS::quotation_pkg;

  $record = new FS::quotation_pkg \%hash;
  $record = new FS::quotation_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::quotation_pkg object represents a quotation package.
FS::quotation_pkg inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item quotationpkgnum

primary key

=item pkgpart

pkgpart

=item locationnum

locationnum

=item start_date

start_date

=item contract_end

contract_end

=item quantity

quantity

=item waive_setup

waive_setup


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new quotation package.  To add the quotation package to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'quotation_pkg'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid quotation package.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('quotationpkgnum')
    || $self->ut_foreign_key('pkgpart', 'part_pkg', 'pkgpart' )
    || $self->ut_foreign_keyn('locationnum', 'cust_location', 'locationnum' )
    || $self->ut_numbern('start_date')
    || $self->ut_numbern('contract_end')
    || $self->ut_numbern('quantity')
    || $self->ut_enum('waive_setup', [ '', 'Y'] )
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub part_pkg {
  my $self = shift;
  qsearchs('part_pkg', { 'pkgpart' => $self->pkgpart } );
}

sub desc {
  my $self = shift;
  $self->part_pkg->pkg;
}

sub setup {
  my $self = shift;
  return '0.00' if $self->waive_setup eq 'Y';
  my $part_pkg = $self->part_pkg;
  #my $setup = $part_pkg->can('base_setup') ? $part_pkg->base_setup
  #                                         : $part_pkg->option('setup_fee');
  my $setup = $part_pkg->option('setup_fee');
  #XXX discounts
  $setup *= $self->quantity if $self->quantity;
  sprintf('%.2f', $setup);

}

sub recur {
  my $self = shift;
  my $part_pkg = $self->part_pkg;
  my $recur = $part_pkg->can('base_recur') ? $part_pkg->base_recur
                                           : $part_pkg->option('recur_fee');
  #XXX discounts
  $recur *= $self->quantity if $self->quantity;
  sprintf('%.2f', $recur);
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

