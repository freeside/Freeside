package FS::Sales_Mixin;

use strict;
use FS::Record qw( qsearchs );
use FS::sales;

=head1 NAME

FS::Agent_Mixin - Mixin class for objects that have an sales person.

=over 4

=item sales

Returns the sales person (see L<FS::sales>) for this object.

=cut

sub sales {
  my $self = shift;
  qsearchs( 'sales', { 'salesnum' => $self->salesnum } );
}

=item salesperson

Returns the sales person name for this object, if any.

=cut

sub salesperson {
  my $self = shift;
  my $sales = $self->sales or return '';
  $sales->salesperson;
}

=back

=head1 BUGS

=cut

1;

