package FS::Bill;

use strict;
use vars qw(@ISA);
use FS::cust_main;

@ISA = qw(FS::cust_main);

warn "FS::Bill depriciated\n";

=head1 NAME

FS::Bill - Legacy stub

=head1 SYNOPSIS

The functionality of FS::Bill has been integrated into FS::cust_main.

=cut

1;
