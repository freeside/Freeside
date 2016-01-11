package FS::h_svc_conferencing;

use strict;
use base qw( FS::h_Common FS::svc_conferencing );

sub table { 'h_svc_conferencing' };

=head1 NAME

FS::h_svc_conferencing - Historical installed conferencing service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_conferencing object represents a historical conferencing service.
FS::h_svc_conferencing inherits from FS::h_Common and FS::svc_conferencing.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_conferencing>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

