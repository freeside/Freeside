package FS::h_svc_acct;
use base qw( FS::h_svc_Radius_Mixin FS::h_Common FS::svc_acct );

use strict;
use vars qw( @ISA $DEBUG );
use Carp qw(carp);
use FS::Record qw(qsearchs);
use FS::svc_domain;
use FS::h_svc_domain;

$DEBUG = 0;

sub table { 'h_svc_acct' };

=head1 NAME

FS::h_svc_acct - Historical account objects

=head1 SYNOPSIS

=head1 METHODS

=over 4

=item svc_domain

=cut

sub svc_domain {
  my $self = shift;
  qsearchs( 'h_svc_domain',
            { 'svcnum' => $self->domsvc },
            FS::h_svc_domain->sql_h_searchs(@_),
          );
}

=item domain

Returns the domain associated with this account.

=cut

sub domain {
  my $self = shift;
  die "svc_acct.domsvc is null for svcnum ". $self->svcnum unless $self->domsvc;

  my $svc_domain = $self->svc_domain(@_) || $self->SUPER::svc_domain()
    or die 'no history svc_domain.svcnum for svc_acct.domsvc ' . $self->domsvc;

  carp 'Using FS::svc_acct record in place of missing FS::h_svc_acct record.'
    if ($svc_domain->isa('FS::svc_acct') and $DEBUG);

  $svc_domain->domain;

}


=back

=head1 DESCRIPTION

An FS::h_svc_acct object represents a historical account.  FS::h_svc_acct
inherits from FS::h_Common and FS::svc_acct.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_acct>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

