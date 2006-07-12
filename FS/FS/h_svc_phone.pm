package FS::h_svc_phone;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_phone;

@ISA = qw( FS::h_Common FS::svc_phone );

sub table { 'h_svc_phone' };

=head1 NAME

FS::h_svc_phone - Historical phone number objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_phone object represents a historical phone number.
FS::h_svc_phone inherits from FS::h_Common and FS::svc_phone.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_phone>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

