package FS::part_pkg;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch );
use FS::pkg_svc;

@ISA = qw( FS::Record );

=head1 NAME

FS::part_pkg - Object methods for part_pkg objects

=head1 SYNOPSIS

  use FS::part_pkg;

  $record = new FS::part_pkg \%hash
  $record = new FS::part_pkg { 'column' => 'value' };

  $custom_record = $template_record->clone;

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  @pkg_svc = $record->pkg_svc;

  $svcnum = $record->svcpart;
  $svcnum = $record->svcpart( 'svc_acct' );

=head1 DESCRIPTION

An FS::part_pkg object represents a billing item definition.  FS::part_pkg
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item pkgpart - primary key (assigned automatically for new billing item definitions)

=item pkg - Text name of this billing item definition (customer-viewable)

=item comment - Text name of this billing item definition (non-customer-viewable)

=item setup - Setup fee expression

=item freq - Frequency of recurring fee

=item recur - Recurring fee expression

=item setuptax - Setup fee tax exempt flag, empty or `Y'

=item recurtax - Recurring fee tax exempt flag, empty or `Y'

=item plan - Price plan

=item plandata - Price plan data

=item disabled - Disabled flag, empty or `Y'

=back

setup and recur are evaluated as Safe perl expressions.  You can use numbers
just as you would normally.  More advanced semantics are not yet defined.

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new billing item definition.  To add the billing item definition to
the database, see L<"insert">.

=cut

sub table { 'part_pkg'; }

=item clone

An alternate constructor.  Creates a new billing item definition by duplicating
an existing definition.  A new pkgpart is assigned and `(CUSTOM) ' is prepended
to the comment field.  To add the billing item definition to the database, see
L<"insert">.

=cut

sub clone {
  my $self = shift;
  my $class = ref($self);
  my %hash = $self->hash;
  $hash{'pkgpart'} = '';
  $hash{'comment'} = "(CUSTOM) ". $hash{'comment'}
    unless $hash{'comment'} =~ /^\(CUSTOM\) /;
  #new FS::part_pkg ( \%hash ); # ?
  new $class ( \%hash ); # ?
}

=item insert

Adds this billing item definition to the database.  If there is an error,
returns the error, otherwise returns false.

=item delete

Currently unimplemented.

=cut

sub delete {
  return "Can't (yet?) delete package definitions.";
# check & make sure the pkgpart isn't in cust_pkg or type_pkgs?
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid billing item definition.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = $self->ut_numbern('pkgpart')
    || $self->ut_text('pkg')
    || $self->ut_text('comment')
    || $self->ut_anything('setup')
    || $self->ut_number('freq')
    || $self->ut_anything('recur')
    || $self->ut_alphan('plan')
    || $self->ut_anything('plandata')
  ;
  return $error if $error;

  $self->setuptax =~ /^(Y?)$/ or return "Illegal setuptax: ". $self->setuptax;
  $self->setuptax($1);

  $self->recurtax =~ /^(Y?)$/ or return "Illegal recrutax: ". $self->recurtax;
  $self->recurtax($1);

  $self->disabled =~ /^(Y?)$/ or return "Illegal disabled: ". $self->disabled;
  $self->disabled($1);

  '';
}

=item pkg_svc

Returns all FS::pkg_svc objects (see L<FS::pkg_svc>) for this package
definition (with non-zero quantity).

=cut

sub pkg_svc {
  my $self = shift;
  grep { $_->quantity } qsearch( 'pkg_svc', { 'pkgpart' => $self->pkgpart } );
}

=item svcpart [ SVCDB ]

Returns the svcpart of a single service definition (see L<FS::part_svc>)
associated with this billing item definition (see L<FS::pkg_svc>).  Returns
false if there not exactly one service definition with quantity 1, or if 
SVCDB is specified and does not match the svcdb of the service definition, 

=cut

sub svcpart {
  my $self = shift;
  my $svcdb = shift;
  my @pkg_svc = $self->pkg_svc;
  return '' if scalar(@pkg_svc) != 1
               || $pkg_svc[0]->quantity != 1
               || ( $svcdb && $pkg_svc[0]->part_svc->svcdb ne $svcdb );
  $pkg_svc[0]->svcpart;
}

=back

=head1 VERSION

$Id: part_pkg.pm,v 1.5 2001-12-27 09:26:13 ivan Exp $

=head1 BUGS

The delete method is unimplemented.

setup and recur semantics are not yet defined (and are implemented in
FS::cust_bill.  hmm.).

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::type_pkgs>, L<FS::pkg_svc>, L<Safe>.
schema.html from the base documentation.

=cut

1;

