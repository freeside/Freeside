package FS::h_svc_acct;

use strict;
use vars qw( @ISA );
use FS::Record qw(qsearchs);
use FS::h_Common;
use FS::svc_acct;
use FS::h_svc_domain;

@ISA = qw( FS::h_Common FS::svc_acct );

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
            FS::h_svc_domain->sql_h_search(@_),
          );
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

