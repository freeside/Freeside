package FS::Misc::Invoicing;
use base qw( Exporter );

use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( spool_formats );

=head1 NAME

FS::Misc::Invoicing - Invoice subroutines

=head1 SYNOPSIS

use FS::Misc::Invoicing qw( spool_formats );

=item spool_formats
  
Returns a list of the invoice spool formats.

=cut

sub spool_formats {
  qw(default oneline billco bridgestone)
}

1;

