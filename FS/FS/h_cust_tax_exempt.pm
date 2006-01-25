package FS::h_cust_tax_exempt;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::cust_tax_exempt;

@ISA = qw( FS::h_Common FS::cust_tax_exempt );

sub table { 'h_cust_tax_exempt' };

=head1 NAME

FS::h_cust_tax_exempt - Historical record of customer tax changes (old-style)

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_cust_tax_exempt object represents historical changes to old-style
customer tax exemptions.  FS::h_cust_tax_exempt inherits from FS::h_Common and
FS::cust_tax_exempt.

=head1 NOTE

Old-style customer tax exemptions are only useful for legacy migrations - if
you are looking for current customer tax exemption data see
L<FS::cust_tax_exempt_pkg>.

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_tax_exempt>, L<FS::cust_tax_exempt_pkg>, L<FS::h_Common>,
L<FS::Record>, schema.html from the base documentation.

=cut

1;

