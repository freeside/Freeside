package FS::h_svc_mailinglist;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::svc_mailinglist;

@ISA = qw( FS::h_Common FS::svc_mailinglist );

sub table { 'h_svc_mailinglist' };

=head1 NAME

FS::h_svc_mailinglist - Historical mailing list objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_svc_mailinglist object represents a historical mailing list.
FS::h_svc_mailinglist inherits from FS::h_Common and FS::svc_mailinglist.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_mailinglist>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

