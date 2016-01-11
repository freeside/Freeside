package FS::h_svc_video;

use strict;
use base qw( FS::h_Common FS::svc_video );

sub table { 'h_svc_video' };

=head1 NAME

FS::h_svc_video - Historical installed video service objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_video object represents a historical video service.
FS::h_svc_video inherits from FS::h_Common and FS::svc_video.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_video>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

