package FS::Invoice;

use strict;
use vars qw(@ISA);
use FS::cust_bill;

@ISA = qw(FS::cust_bill);

warn "FS::Invoice depriciated\n";

=head1 NAME

FS::Invoice - Legacy stub

=head1 SYNOPSIS

The functionality of FS::Invoice has been integrated in FS::cust_bill.

=cut

1;

