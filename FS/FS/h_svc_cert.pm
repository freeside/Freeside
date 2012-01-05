package FS::h_svc_cert;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_cert;

@ISA = qw( FS::h_Common FS::svc_cert );

sub table { 'h_svc_cert' };

=head1 NAME

FS::h_svc_cert - Historical certificate service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_cert object represents a historical certificate service.
FS::h_svc_cert inherits from FS::h_Common and FS::svc_cert.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_cert>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

