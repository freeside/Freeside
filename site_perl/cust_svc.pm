package FS::cust_svc;

use strict;
use vars qw( @ISA );
use Carp qw( cluck );
use FS::Record qw( qsearchs );
use FS::cust_pkg;
use FS::part_pkg;
use FS::part_svc;
use FS::svc_acct;
use FS::svc_acct_sm;
use FS::svc_domain;

@ISA = qw( FS::Record );

=head1 NAME

FS::cust_svc - Object method for cust_svc objects

=head1 SYNOPSIS

  use FS::cust_svc;

  $record = new FS::cust_svc \%hash
  $record = new FS::cust_svc { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  ($label, $value) = $record->label;

=head1 DESCRIPTION

An FS::cust_svc represents a service.  FS::cust_svc inherits from FS::Record.
The following fields are currently supported:

=over 4

=item svcnum - primary key (assigned automatically for new services)

=item pkgnum - Package (see L<FS::cust_pkg>)

=item svcpart - Service definition (see L<FS::part_svc>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new service.  To add the refund to the database, see L<"insert">.
Services are normally created by creating FS::svc_ objects (see
L<FS::svc_acct>, L<FS::svc_domain>, and L<FS::svc_acct_sm>, among others).

=cut

sub table { 'cust_svc'; }

=item insert

Adds this service to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this service from the database.  If there is an error, returns the
error, otherwise returns false.

Called by the cancel method of the package (see L<FS::cust_pkg>).

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid service.  If there is an error,
returns the error, otehrwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('svcnum')
    || $self->ut_numbern('pkgnum')
    || $self->ut_number('svcpart')
  ;
  return $error if $error;

  return "Unknown pkgnum"
    unless ! $self->pkgnum
      || qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );

  return "Unknown svcpart" unless
    qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );

  ''; #no error
}

=item label

Returns a list consisting of:
- The name of this service (from part_svc)
- A meaningful identifier (username, domain, or mail alias)
- The table name (i.e. svc_domain) for this service

=cut

sub label {
  my $self = shift;
  my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );
  my $svcdb = $part_svc->svcdb;
  my $svc_x = qsearchs( $svcdb, { 'svcnum' => $self->svcnum } );
  my $svc = $part_svc->svc;
  my $tag;
  if ( $svcdb eq 'svc_acct' ) {
    $tag = $svc_x->getfield('username');
  } elsif ( $svcdb eq 'svc_acct_sm' ) {
    my $domuser = $svc_x->domuser eq '*' ? '(anything)' : $svc_x->domuser;
    my $svc_domain = qsearchs ( 'svc_domain', { 'svcnum' => $svc_x->domsvc } );
    my $domain = $svc_domain->domain;
    $tag = "$domuser\@$domain";
  } elsif ( $svcdb eq 'svc_domain' ) {
    $tag = $svc_x->getfield('domain');
  } else {
    cluck "warning: asked for label of unsupported svcdb; using svcnum";
    $tag = $svc_x->getfield('svcnum');
  }
  $svc, $tag, $svcdb;
}

=back

=head1 VERSION

$Id: cust_svc.pm,v 1.5 1998-12-29 11:59:47 ivan Exp $

=head1 BUGS

Behaviour of changing the svcpart of cust_svc records is undefined and should
possibly be prohibited, and pkg_svc records are not checked.

pkg_svc records are not checked in general (here).

Deleting this record doesn't check or delete the svc_* record associated
with this record.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::part_svc>, L<FS::pkg_svc>, 
schema.html from the base documentation

=head1 HISTORY

ivan@voicenet.com 97-jul-10,14

no TableUtil, no FS::Lock ivan@sisd.com 98-mar-7

pod ivan@sisd.com 98-sep-21

$Log: cust_svc.pm,v $
Revision 1.5  1998-12-29 11:59:47  ivan
mostly properly OO, some work still to be done with svc_ stuff

Revision 1.4  1998/11/12 07:58:15  ivan
added svcdb to label

Revision 1.3  1998/11/12 03:45:38  ivan
use FS::table_name for all tables qsearch()'ed

Revision 1.2  1998/11/12 03:32:46  ivan
added label method


=cut

1;

