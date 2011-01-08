package FS::h_svc_port;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_port;

@ISA = qw( FS::h_Common FS::svc_port );

sub table { 'h_svc_port' };

=head1 NAME

FS::h_svc_port - Historical port objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_port object represents a historical customer port.  FS::h_svc_port
inherits from FS::h_Common and FS::svc_port.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_port>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

