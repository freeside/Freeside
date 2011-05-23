package FS::h_svc_dish;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_dish;

@ISA = qw( FS::h_Common FS::svc_dish );

sub table { 'h_svc_dish' };

=head1 NAME

FS::h_svc_dish - Historical Dish Network service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_dish object represents a historical Dish Network service.
FS::h_svc_dish inherits from FS::h_Common and FS::svc_dish.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_dish>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

