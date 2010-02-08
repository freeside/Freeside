package FS::h_svc_pbx;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_pbx;

@ISA = qw( FS::h_Common FS::svc_pbx );

sub table { 'h_svc_pbx' };

=head1 NAME

FS::h_svc_pbx - Historical PBX objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_pbx object represents a historical PBX tenant.  FS::h_svc_pbx
inherits from FS::h_Common and FS::svc_pbx.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_pbx>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

