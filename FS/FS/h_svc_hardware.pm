package FS::h_svc_hardware;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_hardware;

@ISA = qw( FS::h_Common FS::svc_hardware );

sub table { 'h_svc_hardware' };

=head1 NAME

FS::h_svc_hardware - Historical installed hardware service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_hardware object represents a historical hardware service.
FS::h_svc_hardware inherits from FS::h_Common and FS::svc_hardware.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_hardware>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

