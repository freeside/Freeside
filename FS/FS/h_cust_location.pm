package FS::h_cust_location;

use strict;
use base qw( FS::h_Common FS::cust_location );

sub table { 'h_cust_location' };

=head1 NAME

FS::h_cust_location - Historical customer location records.

=head1 DESCRIPTION

An FS::h_cust_location object represents historical changes to a customer
location record.  These records normally don't change, so this isn't 
terribly useful.

=head1 SEE ALSO

L<FS::cust_location>,  L<FS::h_Common>, L<FS::Record>, schema.html from the 
base documentation.

=cut

1;

