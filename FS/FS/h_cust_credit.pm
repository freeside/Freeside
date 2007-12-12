package FS::h_cust_credit;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::cust_credit;

@ISA = qw( FS::h_Common FS::cust_credit );

sub table { 'h_cust_credit' };

=head1 NAME

FS::h_cust_credit - Historical record of customer credit changes

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_cust_credit object represents historical changes to credits.
FS::h_cust_credit inherits from FS::h_Common and FS::cust_credit.

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_credit>,  L<FS::h_Common>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

