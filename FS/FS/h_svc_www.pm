package FS::h_svc_www;

use strict;
use vars qw( @ISA );
se FS::Record qw(qsearchs);
use FS::h_Common;
use FS::svc_www;
use FS::h_domain_record;

@ISA = qw( FS::h_Common FS::svc_www );

sub table { 'h_svc_www' };

=head1 NAME

FS::h_svc_www - Historical web virtual host objects

=head1 SYNOPSIS

=head1 METHODS

=over 4

=item domain_record

=cut

sub domain_record {
  my $self = shift;
  qsearchs( 'h_domain_record',
            { 'recnum' => $self->recnum },
            FS::h_domain_record->sql_h_search(@_),
          );
}

=back

=head1 DESCRIPTION

An FS::h_svc_www object represents a historical web virtual host.
FS::h_svc_www inherits from FS::h_Common and FS::svc_www.

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::svc_www>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

