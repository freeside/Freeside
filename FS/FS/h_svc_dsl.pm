package FS::h_svc_dsl;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_dsl;

@ISA = qw( FS::h_Common FS::svc_dsl );

sub table { 'h_svc_dsl' };

=head1 NAME

FS::h_svc_dsl - Historical DSL service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_dsl object represents a historical DSL service.
FS::h_svc_dsl inherits from FS::h_Common and FS::svc_dsl.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_dsl>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

