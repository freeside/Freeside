package FS::h_svc_external;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_external;

@ISA = qw( FS::h_Common FS::svc_external );

sub table { 'h_svc_external' };

=head1 NAME

FS::h_svc_external - Historical externally tracked service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_external object represents a historical externally tracked service.
FS::h_svc_external inherits from FS::h_Common and FS::svc_external.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_external>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

