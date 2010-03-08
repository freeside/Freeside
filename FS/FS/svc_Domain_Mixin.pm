package FS::svc_Domain_Mixin;

use strict;
use FS::Conf;
use FS::Record qw(qsearch qsearchs);
use FS::part_svc;
use FS::cust_pkg;
use FS::cust_svc;
use FS::svc_domain;

=head1 NAME

FS::svc_Domain_Mixin - Mixin class for svc_classes with a domsvc field

=head1 SYNOPSIS

package FS::svc_table;
use base qw( FS::svc_Domain_Mixin FS::svc_Common );

=head1 DESCRIPTION

This is a mixin class for svc_ classes that contain a domsvc field linking to
a domain (see L<FS::svc_domain>).

=head1 METHODS

=over 4

=item domain [ END_TIMESTAMP [ START_TIMESTAMP ] ]

Returns the domain associated with this account.

END_TIMESTAMP and START_TIMESTAMP can optionally be passed when dealing with
history records.

=cut

sub domain {
  my $self = shift;
  #die "svc_acct.domsvc is null for svcnum ". $self->svcnum unless $self->domsvc;
  return '' unless $self->domsvc;
  my $svc_domain = $self->svc_domain(@_)
    or die "no svc_domain.svcnum for domsvc ". $self->domsvc;
  $svc_domain->domain;
}

=item svc_domain

Returns the FS::svc_domain record for this account's domain (see
L<FS::svc_domain>).

=cut

# FS::h_svc_acct has a history-aware svc_domain override

sub svc_domain {
  my $self = shift;
  $self->{'_domsvc'}
    ? $self->{'_domsvc'}
    : qsearchs( 'svc_domain', { 'svcnum' => $self->domsvc } );
}

=item domain_select_hash %OPTIONS

Object or class method.

Returns a hash SVCNUM => DOMAIN ...  representing the domains this customer
may at present purchase.

Currently available options are: I<pkgnum> and I<svcpart>.

=cut

sub domain_select_hash {
  my ($self, %options) = @_;
  my %domains = ();

  my $conf = new FS::Conf;

  my $part_svc;
  my $cust_pkg;

  if (ref($self)) {
    $part_svc = $self->part_svc;
    $cust_pkg = $self->cust_svc->cust_pkg
      if $self->cust_svc;
  }

  $part_svc = qsearchs('part_svc', { 'svcpart' => $options{svcpart} })
    if $options{'svcpart'};

  $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $options{pkgnum} })
    if $options{'pkgnum'};

  if ($part_svc && ( $part_svc->part_svc_column('domsvc')->columnflag eq 'S'
                  || $part_svc->part_svc_column('domsvc')->columnflag eq 'F')) {
    %domains = map { $_->svcnum => $_->domain }
               map { qsearchs('svc_domain', { 'svcnum' => $_ }) }
               split(',', $part_svc->part_svc_column('domsvc')->columnvalue);
  }elsif ($cust_pkg && !$conf->exists('svc_acct-alldomains') ) {
    %domains = map { $_->svcnum => $_->domain }
               map { qsearchs('svc_domain', { 'svcnum' => $_->svcnum }) }
               map { qsearch('cust_svc', { 'pkgnum' => $_->pkgnum } ) }
               qsearch('cust_pkg', { 'custnum' => $cust_pkg->custnum });
  }else{
    %domains = map { $_->svcnum => $_->domain } qsearch('svc_domain', {} );
  }

  if ($part_svc && $part_svc->part_svc_column('domsvc')->columnflag eq 'D') {
    my $svc_domain = qsearchs('svc_domain',
      { 'svcnum' => $part_svc->part_svc_column('domsvc')->columnvalue } );
    if ( $svc_domain ) {
      $domains{$svc_domain->svcnum}  = $svc_domain->domain;
    }else{
      warn "unknown svc_domain.svcnum for part_svc_column domsvc: ".
           $part_svc->part_svc_column('domsvc')->columnvalue;

    }
  }

  (%domains);
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>

=cut

1;
