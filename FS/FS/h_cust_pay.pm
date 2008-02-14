package FS::h_cust_pay;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::cust_pay;

@ISA = qw( FS::h_Common FS::cust_pay );

sub table { 'h_cust_pay' };

=head1 NAME

FS::h_cust_pay - Historical record of customer payment changes

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_cust_pay object represents historical changes to payments.
FS::h_cust_pay inherits from FS::h_Common and FS::cust_pay.

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_pay>,  L<FS::h_Common>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

