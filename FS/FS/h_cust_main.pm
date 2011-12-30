package FS::h_cust_main;

use strict;
use base qw( FS::h_Common FS::cust_main );

sub table { 'h_cust_main' };

=head1 NAME

FS::h_cust_main - Historical customer information records.

=head1 DESCRIPTION

An FS::h_cust_main object represents historical changes to a 
customer record (L<FS::cust_main>).

=head1 SEE ALSO

L<FS::cust_main>,  L<FS::h_Common>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

