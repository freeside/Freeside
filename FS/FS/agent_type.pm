package FS::agent_type;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch dbh );
use FS::m2m_Common;
use FS::agent;
use FS::type_pkgs;

@ISA = qw( FS::m2m_Common FS::Record );

=head1 NAME

FS::agent_type - Object methods for agent_type records

=head1 SYNOPSIS

  use FS::agent_type;

  $record = new FS::agent_type \%hash;
  $record = new FS::agent_type { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $hashref = $record->pkgpart_hashref;
  #may purchase $pkgpart if $hashref->{$pkgpart};

  @type_pkgs = $record->type_pkgs;

  @pkgparts = $record->pkgpart;

=head1 DESCRIPTION

An FS::agent_type object represents an agent type.  Every agent (see
L<FS::agent>) has an agent type.  Agent types define which packages (see
L<FS::part_pkg>) may be purchased by customers (see L<FS::cust_main>), via 
FS::type_pkgs records (see L<FS::type_pkgs>).  FS::agent_type inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item typenum - primary key (assigned automatically for new agent types)

=item atype - Text name of this agent type

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new agent type.  To add the agent type to the database, see
L<"insert">.

=cut

sub table { 'agent_type'; }

=item insert

Adds this agent type to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this agent type from the database.  Only agent types with no agents
can be deleted.  If there is an error, returns the error, otherwise returns
false.

=cut

sub delete {
  my $self = shift;

  return "Can't delete an agent_type with agents!"
    if qsearch( 'agent', { 'typenum' => $self->typenum } );

  $self->SUPER::delete;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid agent type.  If there is an
error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my $self = shift;

  $self->ut_numbern('typenum')
  or $self->ut_text('atype')
  or $self->SUPER::check;

}

=item pkgpart_hashref

Returns a hash reference.  The keys of the hash are pkgparts.  The value is
true iff this agent may purchase the specified package definition.  See
L<FS::part_pkg>.

=cut

sub pkgpart_hashref {
  my $self = shift;
  my %pkgpart;
  $pkgpart{$_}++ foreach $self->pkgpart;
  \%pkgpart;
}

=item type_pkgs

Returns all FS::type_pkgs objects (see L<FS::type_pkgs>) for this agent type.

=cut

sub type_pkgs {
  my $self = shift;
  qsearch('type_pkgs', { 'typenum' => $self->typenum } );
}

=item type_pkgs_enabled

Returns all FS::type_pkg objects (see L<FS::type_pkgs>) that link to enabled
package definitions (see L<FS::part_pkg>).

An additional strange feature is that the returned type_pkg objects also have
all fields of the associated part_pkg object.

=cut

sub type_pkgs_enabled {
  my $self = shift;
  qsearch({
    'table'     => 'type_pkgs',
    'addl_from' => 'JOIN part_pkg USING ( pkgpart )',
    'hashref'   => { 'typenum' => $self->typenum },
    'extra_sql' => " AND ( disabled = '' OR disabled IS NULL )".
                   " ORDER BY pkg",
  });
}

=item pkgpart

Returns the pkgpart of all package definitions (see L<FS::part_pkg>) for this
agent type.

=cut

sub pkgpart {
  my $self = shift;

  #map $_->pkgpart, $self->type_pkgs;

  my $sql = 'SELECT pkgpart FROM type_pkgs WHERE typenum = ?';
  my $sth = dbh->prepare($sql)    or die  dbh->errstr;
  $sth->execute( $self->typenum ) or die $sth->errstr;
  map $_->[0], @{ $sth->fetchall_arrayref };
}

=back

=head1 BUGS

type_pkgs_enabled should order itself by something (pkg?)

type_pkgs_enabled should populate something that caches for the part_pkg method
rather than add fields to this object, right?  In fact we need a "poop" object
framework that does that automatically for any joined search at some point....
right?

=head1 SEE ALSO

L<FS::Record>, L<FS::agent>, L<FS::type_pkgs>, L<FS::cust_main>,
L<FS::part_pkg>, schema.html from the base documentation.

=cut

1;

