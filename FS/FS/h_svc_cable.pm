package FS::h_svc_cable;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_cable;

@ISA = qw( FS::h_Common FS::svc_cable );

sub table { 'h_svc_cable' };

=head1 NAME

FS::h_svc_cable - Historical PBX objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_cable object represents a historical cable subscriber.
FS::h_svc_cable inherits from FS::h_Common and FS::svc_cable.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_cable>, L<FS::Record>

=cut

1;

