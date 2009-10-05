package FS::cust_bill_pkg_display;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::cust_bill_pkg_display - Object methods for cust_bill_pkg_display records

=head1 SYNOPSIS

  use FS::cust_bill_pkg_display;

  $record = new FS::cust_bill_pkg_display \%hash;
  $record = new FS::cust_bill_pkg_display { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg_display object represents line item display information.
FS::cust_bill_pkg_display inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item billpkgdisplaynum

primary key

=item billpkgnum

billpkgnum

=item section

section

=cut

sub section {
  my ( $self, $value ) = @_;
  if ( defined($value) ) {
    $self->setfield('section', $value);
  } else {
    my $section = $self->getfield('section');
    unless ($section) {
      my $part_pkg = $self->cust_bill_pkg->part_pkg;
      $section = $part_pkg->categoryname if $part_pkg;
    }
    $section;
  }
}

=item post_total

post_total

=item type

type

=item summary

summary

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new line item display object.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_bill_pkg_display'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid line item display object.
If there is an error, returns the error, otherwise returns false.  Called by
the insert and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('billpkgdisplaynum')
    || $self->ut_number('billpkgnum')
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg', 'billpkgnum')
    || $self->ut_textn('section')
    || $self->ut_enum('post_total', [ '', 'Y' ])
    || $self->ut_enum('type', [ '', 'S', 'R', 'U' ])
    || $self->ut_enum('summary', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item cust_bill_pkg

Returns the associated cust_bill_pkg (see L<FS::cust_bill_pkg>) for this
line item display object.

=cut

sub cust_bill_pkg {
  my $self = shift;
  qsearchs( 'cust_bill_pkg', { 'billpkgnum' => $self->billpkgnum } ) ;
}

=back

=head1 BUGS



=head1 SEE ALSO

L<FS::Record>, L<FS::cust_bill_pkg>, schema.html from the base documentation.

=cut

1;

