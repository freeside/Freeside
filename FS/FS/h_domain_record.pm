package FS::h_domain_record;

use strict;
use vars qw( @ISA );
use FS::h_Common;
use FS::domain_record;

@ISA = qw( FS::h_Common FS::domain_record );

sub table { 'h_domain_record' };

=head1 NAME

FS::h_domain_record - Historical DNS entry objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_domain_record object represents a historical entry in a DNS zone.
FS::h_domain_record inherits from FS::h_Common and FS::domain_record.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_external>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

