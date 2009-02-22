package FS::h_cust_pkg;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::cust_pkg;

@ISA = qw( FS::h_Common FS::cust_pkg );

sub table { 'h_cust_pkg' };

=head1 NAME

FS::h_cust_pkg - Historical record of customer package changes

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_cust_pkg object represents historical changes to packages.
FS::h_cust_pkg inherits from FS::h_Common and FS::cust_pkg.

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_pkg>,  L<FS::h_Common>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;


