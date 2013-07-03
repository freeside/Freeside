package FS::GeocodeCache;

use strict;
use vars qw($conf $DEBUG);
use base qw( FS::geocode_Mixin );
use FS::Record qw( qsearch qsearchs );
use FS::Conf;
use FS::Misc::Geo;

use Data::Dumper;

FS::UID->install_callback( sub { $conf = new FS::Conf; } );

$DEBUG = 0;

=head1 NAME

FS::GeocodeCache - An address undergoing the geocode process.

=head1 SYNOPSIS

  use FS::GeocodeCache;

  $record = FS::GeocodeCache->standardize(%location_hash);

=head1 DESCRIPTION

An FS::GeocodeCache object represents a street address in the process of 
being geocoded.  FS::GeocodeCache inherits from FS::geocode_Mixin.

Most methods on this object throw an exception on error.

FS::GeocodeCache has the following fields, with the same meaning as in 
L<FS::cust_location>:

=over 4

=item address1

=item address2

=item city

=item county

=item state

=item zip

=item latitude

=item longitude

=item addr_clean

=item country

=item censustract

=item geocode

=item district

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new cache object.  For internal use.  See C<standardize>.

=cut

# minimalist constructor
sub new {
  my $class = shift;
  my $self = {
    company     => '',
    address1    => '',
    address2    => '',
    city        => '',
    state       => '',
    zip         => '',
    country     => '',
    latitude    => '',
    longitude   => '',
    addr_clean  => '',
    censustract => '',
    @_
  };
  bless $self, $class;
}

# minimalist accessor, for compatibility with geocode_Mixin
sub get {
  $_[0]->{$_[1]}
}

sub set {
  $_[0]->{$_[1]} = $_[2];
}

sub location_hash { %{$_[0]} };

=item set_censustract

Look up the censustract, if it's not already filled in, and return it.
On error, sets 'error' and returns nothing.

This uses the "get_censustract_*" methods in L<FS::Misc::Geo>; currently
the only one is 'ffiec'.

=cut

sub set_censustract {
  my $self = shift;

  if ( $self->get('censustract') =~ /^\d{9}\.\d{2}$/ ) {
    return $self->get('censustract');
  }
  my $censusyear = $conf->config('census_year');
  return if !$censusyear;

  my $method = 'ffiec';
  # configurable censustract-only lookup goes here if it's ever needed.
  $method = "get_censustract_$method";
  my $censustract = eval { FS::Misc::Geo->$method($self, $censusyear) };
  $self->set("censustract_error", $@);
  $self->set("censustract", $censustract);
}

=item set_coord

Set the latitude and longitude fields if they're not already set.  Returns
those values, in order.

=cut

sub set_coord { # the one in geocode_Mixin will suffice
  my $self = shift;
  if ( !$self->get('latitude') || !$self->get('longitude') ) {
    $self->SUPER::set_coord;
    $self->set('coord_error', $@);
  }
  return $self->get('latitude'), $self->get('longitude');
}

=head1 CLASS METHODS

=over 4

=item standardize LOCATION

Given a location hash or L<FS::geocode_Mixin> object, standardize the 
address using the configured method and return an L<FS::GeocodeCache> 
object.

The methods are the "standardize_*" functions in L<FS::Geo::Misc>.

=cut

sub standardize {
  my $class = shift;
  my $location = shift;
  $location = { $location->location_hash }
    if UNIVERSAL::can($location, 'location_hash');

  local $Data::Dumper::Terse = 1;
  warn "standardizing location:\n".Dumper($location) if $DEBUG;

  my $method = $conf->config('address_standardize_method');

  if ( $method ) {
    $method = "standardize_$method";
    my $new_location = eval { FS::Misc::Geo->$method( $location ) };
    if ( $new_location ) {
      $location = {
        addr_clean => 'Y',
        %$new_location
        # standardize_* can return an address with addr_clean => '' if
        # the address is somehow questionable
      }
    }
    else {
      # XXX need an option to decide what to do on error
      $location->{'addr_clean'} = '';
      $location->{'error'} = $@;
    }
    warn "result:\n".Dumper($location) if $DEBUG;
  }
  # else $location = $location
  my $cache = $class->new(%$location);
  return $cache;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

