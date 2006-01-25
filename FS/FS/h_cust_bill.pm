package FS::h_cust_bill;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::cust_bill;

@ISA = qw( FS::h_Common FS::cust_bill );

sub table { 'h_cust_bill' };

=head1 NAME

FS::h_cust_bill - Historical record of customer tax changes (old-style)

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_cust_bill object represents historical changes to invoices.
FS::h_cust_bill inherits from FS::h_Common and FS::cust_bill.

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_bill>,  L<FS::h_Common>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

