package FS::Report;

use strict;

=head1 NAME

FS::Report - Report data objects

=head1 SYNOPSIS

  #see the more speicific report objects, currently only FS::Report::Table

=head1 DESCRIPTION

See the more specific report objects, currently only FS::Report::Table

=head1 METHODS

=over 4

=item new [ OPTION => VALUE ... ]

Constructor.  Takes a list of options and their values.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = @_ ? ( ref($_[0]) ? shift : { @_ } ) : {};
  bless( $self, $class );
}

=back

=head1 BUGS

Documentation.

=head1 SEE ALSO

L<FS::Report::Table>, reports in the web interface.

=cut

1;
