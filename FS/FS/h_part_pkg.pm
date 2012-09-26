package FS::h_part_pkg;

use strict;
use vars qw( @ISA );
use base qw(FS::h_Common FS::part_pkg);

sub table { 'h_part_pkg' };

sub _rebless {}; # don't try to rebless these

=head1 NAME

FS::h_part_pkg - Historical record of package definition.

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_part_pkg object represents historical changes to package
definitions.

=head1 BUGS

Many important properties of a part_pkg are in other tables, especially
plan options, service allotments, and link/bundle relationships.  The 
methods to access those from the part_pkg will work, but they're 
really accessing current, not historical, data.  Be careful.

=head1 SEE ALSO

L<FS::part_pkg>,  L<FS::h_Common>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

