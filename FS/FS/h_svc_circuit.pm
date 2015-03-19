package FS::h_svc_circuit;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_circuit;

@ISA = qw( FS::h_Common FS::svc_circuit );

sub table { 'h_svc_circuit' };

=head1 NAME

FS::h_svc_circuit - Historical telecom circuit service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_circuit object represents a historical circuit service.
FS::h_svc_circuit inherits from FS::h_Common and FS::svc_circuit.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_circuit>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

