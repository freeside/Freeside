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

=head1 HISTORY

ivan@voicenet.com 97-jul-24 - 25 - 28

use Safe; evaluate all fees with perl (still on TODO list until I write
some examples & test opmask to see if we can read db)
%hash=$obj->hash later ivan@sisd.com 98-mar-13

packages with no next bill date start at $time not time, this should
eliminate the last of the problems with billing at a past date
also rewrite the invoice priting logic not to print invoices for things
that haven't happended yet and update $cust_bill->printed when we print
so PAST DUE notices work, and s/date/_date/ 
ivan@sisd.com 98-jun-4

more logic for past due stuff - packages with no next bill date start
at $cust_pkg->setup || $time ivan@sisd.com 98-jul-13

moved a few things in collection logic; negative charges should work
ivan@sisd.com 98-aug-6

pod, moved everything to FS::cust_main ivan@sisd.com 98-sep-19

=cut

1;
