package FS::h_inventory_item;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::inventory_item;

@ISA = qw( FS::h_Common FS::inventory_item );

sub table { 'h_inventory_item' };

=head1 NAME

FS::h_inventory_item - Historical record of inventory item activity

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_inventory_item object represents a change in the state of an 
inventory item.

=head1 BUGS

=head1 SEE ALSO

L<FS::inventory_item>,  L<FS::h_Common>, L<FS::Record>, schema.html from the 
base documentation.

=cut

1;

