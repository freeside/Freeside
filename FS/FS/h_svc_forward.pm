package FS::h_svc_forward;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Record qw(qsearchs);
use FS::h_Common;
use FS::svc_forward;
use FS::svc_acct;
use FS::h_svc_acct;

use Carp qw(carp);

$DEBUG = 0;

@ISA = qw( FS::h_Common FS::svc_forward );

sub table { 'h_svc_forward' };

=head1 NAME

FS::h_svc_forward - Historical mail forwarding alias objects

=head1 SYNOPSIS

=head1 METHODS

=over 4

=item srcsvc_acct 

=cut

sub srcsvc_acct {
  my $self = shift;

  local($FS::Record::qsearch_qualify_columns) = 0;

  my $h_svc_acct = qsearchs(
    'h_svc_acct',
    { 'svcnum' => $self->srcsvc },
    FS::h_svc_acct->sql_h_searchs(@_),
  ) || $self->SUPER::srcsvc_acct
    or die "no history svc_acct.svcnum for svc_forward.srcsvc ". $self->srcsvc;

  carp 'Using svc_acct in place of missing h_svc_acct record.'
    if ($h_svc_acct->isa('FS::domain_record') and $DEBUG);

  return $h_svc_acct;

}

=item dstsvc_acct

=cut

sub dstsvc_acct {
  my $self = shift;

  local($FS::Record::qsearch_qualify_columns) = 0;

  my $h_svc_acct = qsearchs(
    'h_svc_acct',
    { 'svcnum' => $self->dstsvc },
    FS::h_svc_acct->sql_h_searchs(@_),
  ) || $self->SUPER::dstsvc_acct
    or die "no history svc_acct.svcnum for svc_forward.dstsvc ". $self->dstsvc;

  carp 'Using svc_acct in place of missing h_svc_acct record.'
    if ($h_svc_acct->isa('FS::domain_record') and $DEBUG);

  return $h_svc_acct;
}

=back

=head1 DESCRIPTION

An FS::h_svc_forward object represents a historical mail forwarding alias.
FS::h_svc_forward inherits from FS::h_Common and FS::svc_forward.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_forward>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

