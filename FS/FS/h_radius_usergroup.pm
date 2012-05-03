package FS::h_radius_usergroup;

use strict;
use base qw( FS::h_Common FS::radius_usergroup );

sub table { 'h_radius_usergroup' };

=head1 NAME

FS::h_radius_usergroup - Historical RADIUS usergroup records.

=head1 DESCRIPTION

An FS::h_radius_usergroup object represents historical changes to an account's
RADIUS group (L<FS::radius_usergroup>).

=head1 SEE ALSO

L<FS::radius_usergroup>,  L<FS::h_Common>, L<FS::Record>

=cut

1;

