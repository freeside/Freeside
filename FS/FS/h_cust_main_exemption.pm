package FS::h_cust_main_exemption;

use strict;
use base qw( FS::h_Common FS::cust_main_exemption );

sub table { 'h_cust_main_exemption' };

=head1 NAME

FS::h_cust_main_exemption - Historical customer tax exemption records.

=head1 SEE ALSO

L<FS::cust_main_exemption>,  L<FS::h_Common>, L<FS::Record>.

=cut

1;

