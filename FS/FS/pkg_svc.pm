package FS::pkg_svc;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::part_pkg;
use FS::part_svc;

@ISA = qw( FS::Record );

=head1 NAME

FS::pkg_svc - Object methods for pkg_svc records

=head1 SYNOPSIS

  use FS::pkg_svc;

  $record = new FS::pkg_svc \%hash;
  $record = new FS::pkg_svc { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $part_pkg = $record->part_pkg;

  $part_svc = $record->part_svc;

=head1 DESCRIPTION

An FS::pkg_svc record links a billing item definition (see L<FS::part_pkg>) to
a service definition (see L<FS::part_svc>).  FS::pkg_svc inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item pkgsvcnum - primary key

=item pkgpart - Billing item definition (see L<FS::part_pkg>)

=item svcpart - Service definition (see L<FS::part_svc>)

=item quantity - Quantity of this service definition that this billing item
definition includes

=item primary_svc - primary flag, empty or 'Y'

=item hidden - 'Y' to hide this service on invoices, null otherwise.

=back

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'pkg_svc'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this record from the database.  If there is an error, returns the
error, otherwise returns false.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my( $new, $old ) = ( shift, shift );

  $old = $new->replace_old unless defined($old);

  return "Can't change pkgpart!" if $old->pkgpart != $new->pkgpart;
  return "Can't change svcpart!" if $old->svcpart != $new->svcpart;

  $new->SUPER::replace($old);
}

=item check

Checks all fields to make sure this is a valid record.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  my $error;
  $error =
       $self->ut_numbern('pkgsvcnum')
    || $self->ut_number('pkgpart')
    || $self->ut_number('svcpart')
    || $self->ut_number('quantity')
    || $self->ut_enum('hidden', [ '', 'Y' ] )
  ;
  return $error if $error;

  return "Unknown pkgpart!" unless $self->part_pkg;
  return "Unknown svcpart!" unless $self->part_svc;

  if ( $self->dbdef_table->column('primary_svc') ) {
    $error = $self->ut_enum('primary_svc', [ '', 'Y' ] );
    return $error if $error;
  }

  $self->SUPER::check;
}

=item part_pkg

Returns the FS::part_pkg object (see L<FS::part_pkg>).

=cut

sub part_pkg {
  my $self = shift;
  qsearchs( 'part_pkg', { 'pkgpart' => $self->pkgpart } );
}

=item part_svc

Returns the FS::part_svc object (see L<FS::part_svc>).

=cut

sub part_svc {
  my $self = shift;
  qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::part_pkg>, L<FS::part_svc>, schema.html from the base
documentation.

=cut

1;

