package FS::h_svc_domain;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_domain;

@ISA = qw( FS::h_Common FS::svc_domain );

sub table { 'h_svc_domain' };

=head1 NAME

FS::h_svc_domain - Historical domain objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_domain object represents a historical domain.  FS::h_svc_domain
inherits from FS::h_Common and FS::svc_domain.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_domain>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

