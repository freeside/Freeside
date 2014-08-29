package FS::location_Mixin;

use strict;
use FS::Record qw( qsearchs );
use FS::cust_location;

=item cust_location

Returns the location object, if any (see L<FS::cust_location>).

=cut

sub cust_location {
  my( $self, %opt ) = @_;

  return '' unless $self->locationnum;

  return $opt{_cache}->{$self->locationnum}
    if $opt{_cache} && $opt{_cache}->{$self->locationnum};

  my $cust_location = 
    qsearchs( 'cust_location', { 'locationnum' => $self->locationnum } );

  $opt{_cache}->{$self->locationnum} = $cust_location
     if $opt{_cache};
  
  $cust_location;
}

=item cust_location_or_main

If this package is associated with a location, returns the locaiton (see
L<FS::cust_location>), otherwise returns the customer (see L<FS::cust_main>).

=cut

sub cust_location_or_main {
  my $self = shift;
  $self->cust_location(@_) || $self->cust_main;
}

=item location_label [ OPTION => VALUE ... ]

Returns the label of the location object (see L<FS::cust_location>).

=cut

sub location_label {
  my $self = shift;
  my $object = $self->cust_location_or_main or return '';
  $object->location_label(@_);
}

=item location_hash

Returns a hash of values for the location, either from the location object,
the cust_main shipping address, or the cust_main address, whichever is present
first.

=cut

sub location_hash {
  my $self = shift;
  my $object = $self->cust_location_or_main;
  $object->location_hash(@_);
}

1;
