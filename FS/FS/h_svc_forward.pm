package FS::h_svc_forward;

use strict;
use vars qw( @ISA );
se FS::Record qw(qsearchs);
use FS::h_Common;
use FS::svc_forward;
use FS::h_svc_acct;

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
  qsearchs( 'h_svc_acct',
            { 'svcnum' => $self->srcsvc },
            FS::h_svc_acct->sql_h_search(@_),
          );
}

=item dstsvc_acct

=cut

sub dstsvc_acct {
  my $self = shift;
  qsearchs( 'h_svc_acct',
            { 'svcnum' => $self->dstsvc },
            FS::h_svc_acct->sql_h_search(@_),
          );
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

