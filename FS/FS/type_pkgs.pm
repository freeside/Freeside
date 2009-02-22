package FS::type_pkgs;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::agent_type;
use FS::part_pkg;

@ISA = qw( FS::Record );

=head1 NAME

FS::type_pkgs - Object methods for type_pkgs records

=head1 SYNOPSIS

  use FS::type_pkgs;

  $record = new FS::type_pkgs \%hash;
  $record = new FS::type_pkgs { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::type_pkgs record links an agent type (see L<FS::agent_type>) to a
billing item definition (see L<FS::part_pkg>).  FS::type_pkgs inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item typepkgnum - primary key

=item typenum - Agent type, see L<FS::agent_type>

=item pkgpart - Billing item definition, see L<FS::part_pkg>

=back

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'type_pkgs'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

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
       $self->ut_numbern('typepkgnum')
    || $self->ut_foreign_key('typenum', 'agent_type', 'typenum' )
    || $self->ut_foreign_key('pkgpart', 'part_pkg',   'pkgpart' )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_pkg

Returns the FS::part_pkg object associated with this record.

=cut

sub part_pkg {
  my $self = shift;
  qsearchs( 'part_pkg', { 'pkgpart' => $self->pkgpart } );
}

=item agent_type

Returns the FS::agent_type object associated with this record.

=cut

sub agent_type {
  my $self = shift;
  qsearchs( 'agent_type', { 'typenum' => $self->typenum } );
}

=cut

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::agent_type>, L<FS::part_pkgs>, schema.html from the base
documentation.

=cut

1;

