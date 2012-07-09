package FS::h_svc_broadband;
use base qw( FS::h_svc_Radius_Mixin FS::h_Common FS::svc_broadband );

use strict;
use vars qw( @ISA );

sub table { 'h_svc_broadband' };

=head1 NAME

FS::h_svc_broadband - Historical broadband connection objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_broadband object represents a historical broadband connection.
FS::h_svc_broadband inherits from FS::h_Common and FS::svc_broadband.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_broadband>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

