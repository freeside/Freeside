package FS::h_svc_realestate;

use strict;
use vars qw( @ISA );
use FS::h_Common;


@ISA = qw( FS::h_Common );

sub table { 'h_svc_realestate' };

=head1 NAME

FS::h_svc_circuit - Historical realestate service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_realestate object

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_realestate>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;
