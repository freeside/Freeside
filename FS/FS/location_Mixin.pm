package FS::location_Mixin;

use strict;
use FS::Record qw( qsearchs );
use FS::cust_location;

=item cust_location

Returns the location object, if any (see L<FS::cust_location>).

=cut

sub cust_location {
  my $self = shift;
  return '' unless $self->locationnum;
  qsearchs( 'cust_location', { 'locationnum' => $self->locationnum } );
}

=item cust_location_or_main

If this package is associated with a location, returns the locaiton (see
L<FS::cust_location>), otherwise returns the customer (see L<FS::cust_main>).

=cut

sub cust_location_or_main {
  my $self = shift;
  $self->cust_location || $self->cust_main;
}

=item location_label [ OPTION => VALUE ... ]

Returns the label of the location object (see L<FS::cust_location>).

=cut

sub location_label {
  my $self = shift;
  my $object = $self->cust_location_or_main;
  $object->location_label(@_);
}

1;
