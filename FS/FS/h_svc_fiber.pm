package FS::h_svc_fiber;

use strict;
use base qw( FS::h_Common FS::svc_fiber );

sub table { 'h_svc_fiber' };

=head1 NAME

FS::h_svc_fiber - Historical installed fiber service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_fiber object represents a historical fiber service.
FS::h_svc_fiber inherits from FS::h_Common and FS::svc_fiber.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_fiber>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

