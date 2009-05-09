package FS::part_svc_column;

use strict;
use vars qw( @ISA );
use FS::Record qw( fields );

@ISA = qw(FS::Record);

=head1 NAME

FS::part_svc_column - Object methods for part_svc_column objects

=head1 SYNOPSIS

  use FS::part_svc_column;

  $record = new FS::part_svc_column \%hash
  $record = new FS::part_svc_column { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_svc_column record represents a service definition column
constraint.  FS::part_svc_column inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item columnnum - primary key (assigned automatcially for new records)

=item svcpart - service definition (see L<FS::part_svc>)

=item columnname - column name in part_svc.svcdb table

=item columnlabel - label for the column

=item columnvalue - default or fixed value for the column

=item columnflag - null or empty (no default), `D' for default, `F' for fixed (unchangeable), `S' for selectable choice, `M' for manual selection from inventory, or `A' for automatic selection from inventory.  For virtual fields, can also be 'X' for excluded.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new column constraint.  To add the column constraint to the database, see L<"insert">.

=cut

sub table { 'part_svc_column'; }

=item insert

Adds this service definition to the database.  If there is an error, returns
the error, otherwise returns false.

=item delete

Deletes this record from the database.  If there is an error, returns the
error, otherwise returns false.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('columnnum')
    || $self->ut_number('svcpart')
    || $self->ut_alpha('columnname')
    || $self->ut_textn('columnlabel')
    || $self->ut_anything('columnvalue')
  ;
  return $error if $error;

  $self->columnflag =~ /^([DFSMAX]?)$/
    or return "illegal columnflag ". $self->columnflag;
  $self->columnflag(uc($1));

  if ( $self->columnflag =~ /^[MA]$/ ) {
    $error =
      $self->ut_foreign_key( 'columnvalue', 'inventory_class', 'classnum' );
    return $error if $error;
  }

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::part_svc>, L<FS::part_pkg>, L<FS::pkg_svc>,
L<FS::cust_svc>, L<FS::svc_acct>, L<FS::svc_forward>, L<FS::svc_domain>,
schema.html from the base documentation.

=cut

1;

