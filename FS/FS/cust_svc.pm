package FS::cust_svc;

use strict;
use vars qw( @ISA );
use Carp qw( cluck );
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_pkg;
use FS::part_pkg;
use FS::part_svc;
use FS::pkg_svc;
use FS::svc_acct;
use FS::svc_acct_sm;
use FS::svc_domain;
use FS::svc_forward;
use FS::domain_record;

@ISA = qw( FS::Record );

sub _cache {
  my $self = shift;
  my ( $hashref, $cache ) = @_;
  if ( $hashref->{'username'} ) {
    $self->{'_svc_acct'} = FS::svc_acct->new($hashref, '');
  }
  if ( $hashref->{'svc'} ) {
    $self->{'_svcpart'} = FS::part_svc->new($hashref);
  }
}

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
L<FS::svc_acct>, L<FS::svc_domain>, and L<FS::svc_forward>, among others).

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

  my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );
  return "Unknown svcpart" unless $part_svc;

  if ( $self->pkgnum ) {
    my $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );
    return "Unknown pkgnum" unless $cust_pkg;
    my $pkg_svc = qsearchs( 'pkg_svc', {
      'pkgpart' => $cust_pkg->pkgpart,
      'svcpart' => $self->svcpart,
    });
    my @cust_svc = qsearch('cust_svc', {
      'pkgnum'  => $self->pkgnum,
      'svcpart' => $self->svcpart,
    });
    return "Already ". scalar(@cust_svc). " ". $part_svc->svc.
           " services for pkgnum ". $self->pkgnum
      if scalar(@cust_svc) >= $pkg_svc->quantity;
  }

  ''; #no error
}

=item part_svc

Returns the definition for this service, as a FS::part_svc object (see
L<FS::part_svc>).

=cut

sub part_svc {
  my $self = shift;
  $self->{'_svcpart'}
    ? $self->{'_svcpart'}
    : qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );
}

=item cust_pkg

Returns the definition for this service, as a FS::part_svc object (see
L<FS::part_svc>).

=cut

sub cust_pkg {
  my $self = shift;
  qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );
}

=item label

Returns a list consisting of:
- The name of this service (from part_svc)
- A meaningful identifier (username, domain, or mail alias)
- The table name (i.e. svc_domain) for this service

=cut

sub label {
  my $self = shift;
  my $svcdb = $self->part_svc->svcdb;
  my $svc_x = $self->svc_x
    or die "can't find $svcdb.svcnum ". $self->svcnum;
  my $tag;
  if ( $svcdb eq 'svc_acct' ) {
    $tag = $svc_x->email;
  } elsif ( $svcdb eq 'svc_acct_sm' ) {
    my $domuser = $svc_x->domuser eq '*' ? '(anything)' : $svc_x->domuser;
    my $svc_domain = qsearchs ( 'svc_domain', { 'svcnum' => $svc_x->domsvc } );
    my $domain = $svc_domain->domain;
    $tag = "$domuser\@$domain";
  } elsif ( $svcdb eq 'svc_forward' ) {
    my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $svc_x->srcsvc } );
    $tag = $svc_acct->email. '->';
    if ( $svc_x->dstsvc ) {
      $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $svc_x->dstsvc } );
      $tag .= $svc_acct->email;
    } else {
      $tag .= $svc_x->dst;
    }
  } elsif ( $svcdb eq 'svc_domain' ) {
    $tag = $svc_x->getfield('domain');
  } elsif ( $svcdb eq 'svc_www' ) {
    my $domain = qsearchs( 'domain_record', { 'recnum' => $svc_x->recnum } );
    $tag = $domain->reczone;
  } else {
    cluck "warning: asked for label of unsupported svcdb; using svcnum";
    $tag = $svc_x->getfield('svcnum');
  }
  $self->part_svc->svc, $tag, $svcdb;
}

=item svc_x

Returns the FS::svc_XXX object for this service (i.e. an FS::svc_acct object or
FS::svc_domain object, etc.)

=cut

sub svc_x {
  my $self = shift;
  my $svcdb = $self->part_svc->svcdb;
  if ( $svcdb eq 'svc_acct' && $self->{'_svc_acct'} ) {
    $self->{'_svc_acct'};
  } else {
    qsearchs( $svcdb, { 'svcnum' => $self->svcnum } );
  }
}

=item seconds_since TIMESTAMP

See L<FS::svc_acct/seconds_since>.  Equivalent to
$cust_svc->svc_x->seconds_since, but more efficient.  Meaningless for records
where B<svcdb> is not "svc_acct".

=cut

#note: implementation here, POD in FS::svc_acct
sub seconds_since {
  my($self, $since) = @_;
  my $dbh = dbh;
  my $sth = $dbh->prepare(' SELECT SUM(logout-login) FROM session
                              WHERE svcnum = ?
                                AND login >= ?
                                AND logout IS NOT NULL'
  ) or die $dbh->errstr;
  $sth->execute($self->svcnum, $since) or die $sth->errstr;
  $sth->fetchrow_arrayref->[0];
}

=back

=head1 VERSION

$Id: cust_svc.pm,v 1.12 2002-02-10 22:06:28 ivan Exp $

=head1 BUGS

Behaviour of changing the svcpart of cust_svc records is undefined and should
possibly be prohibited, and pkg_svc records are not checked.

pkg_svc records are not checked in general (here).

Deleting this record doesn't check or delete the svc_* record associated
with this record.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, L<FS::part_svc>, L<FS::pkg_svc>, 
schema.html from the base documentation

=cut

1;

