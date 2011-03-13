package FS::geocode_Mixin;

use strict;
use vars qw( $DEBUG $me );
use Carp;
use Locale::Country;
use FS::Record qw( qsearchs qsearch );
use FS::Conf;
use FS::cust_pkg;
use FS::cust_location;
use FS::cust_tax_location;
use FS::part_pkg;

$DEBUG = 0;
$me = '[FS::geocode_Mixin]';

=head1 NAME

FS::geocode_Mixin - Mixin class for records that contain address and other
location fields.

=head1 SYNOPSIS

  package FS::some_table;
  use base ( FS::geocode_Mixin FS::Record );

=head1 DESCRIPTION

FS::geocode_Mixin - This is a mixin class for records that contain address
and other location fields.

=head1 METHODS

=over 4

=cut

=item location_hash

Returns a list of key/value pairs, with the following keys: address1, address2,
city, county, state, zip, country, geocode, location_type, location_number,
location_kind.  The shipping address is used if present.

=cut

#geocode dependent on tax-ship_address config

sub location_hash {
  my $self = shift;
  my $prefix = $self->has_ship_address ? 'ship_' : '';

  map { my $method = ($_ eq 'geocode') ? $_ : $prefix.$_;
        $_ => $self->get($method);
      }
      qw( address1 address2 city county state zip country geocode 
	location_type location_number location_kind );
}

=item location_label [ OPTION => VALUE ... ]

Returns the label of the service location (see analog in L<FS::cust_location>) for this customer.

Options are

=over 4

=item join_string

used to separate the address elements (defaults to ', ')

=item escape_function

a callback used for escaping the text of the address elements

=back

=cut

sub location_label {
  my $self = shift;
  my %opt = @_;

  my $separator = $opt{join_string} || ', ';
  my $escape = $opt{escape_function} || sub{ shift };
  my $ds = $opt{double_space} || '  ';
  my $line = '';
  my $cydefault = 
    $opt{'countrydefault'} || FS::Conf->new->config('countrydefault') || 'US';
  my $prefix = $self->has_ship_address ? 'ship_' : '';

  my $notfirst = 0;
  foreach (qw ( address1 address2 ) ) {
    my $method = "$prefix$_";
    $line .= ($notfirst ? $separator : ''). &$escape($self->$method)
      if $self->$method;
    $notfirst++;
  }

  if ( $self->get($prefix.'location_type') ) {
    my %location_type;
    if ( 1 ) { #ikano, switch on via config
      { no warnings 'void';
        eval { 'use FS::part_export::ikano;' };
        die $@ if $@;
      }
      %location_type = FS::part_export::ikano->location_types;
    } else {
      %location_type = (); #?
    }

    $line .= ' '.&$escape( $location_type{ $self->get($prefix.'location_type') }
                                       ||  $self->get($prefix.'location_type')
                         );
  }

  $line .= ' '. &$escape($self->get($prefix.'location_number'))
    if $self->get($prefix.'location_number');

  $notfirst = 0;
  foreach (qw ( city county state zip ) ) {
    my $method = "$prefix$_";
    if ( $self->$method ) {
      $line .= ' (' if $method eq 'county';
      $line .= ($notfirst ? ' ' : $separator). &$escape($self->$method);
      $line .= ' )' if $method eq 'county';
      $notfirst++;
    }
  }
  $line .= $separator. &$escape(code2country($self->country))
    if $self->country ne $cydefault;

  $line;
}

=item geocode DATA_VENDOR

Returns a value for the customer location as encoded by DATA_VENDOR.
Currently this only makes sense for "CCH" as DATA_VENDOR.

=cut

sub geocode {
  my ($self, $data_vendor) = (shift, shift);  #always cch for now

  my $geocode = $self->get('geocode');  #XXX only one data_vendor for geocode
  return $geocode if $geocode;

  my $prefix =
   ( FS::Conf->new->exists('tax-ship_address') && $self->has_ship_address )
   ? 'ship_'
   : '';

  my($zip,$plus4) = split /-/, $self->get("${prefix}zip")
    if $self->country eq 'US';

  $zip ||= '';
  $plus4 ||= '';
  #CCH specific location stuff
  my $extra_sql = "AND plus4lo <= '$plus4' AND plus4hi >= '$plus4'";

  my @cust_tax_location =
    qsearch( {
               'table'     => 'cust_tax_location', 
               'hashref'   => { 'zip' => $zip, 'data_vendor' => $data_vendor },
               'extra_sql' => $extra_sql,
               'order_by'  => 'ORDER BY plus4hi',#overlapping with distinct ends
             }
           );
  $geocode = $cust_tax_location[0]->geocode
    if scalar(@cust_tax_location);

  $geocode;
}

=item alternize

Attempts to parse data for location_type and location_number from address1
and address2.

=cut

sub alternize {
  my $self = shift;
  my $prefix = $self->has_ship_address ? 'ship_' : '';

  return '' if $self->get($prefix.'location_type')
            || $self->get($prefix.'location_number');

  my %parse;
  if ( 1 ) { #ikano, switch on via config
    { no warnings 'void';
      eval { 'use FS::part_export::ikano;' };
      die $@ if $@;
    }
    %parse = FS::part_export::ikano->location_types_parse;
  } else {
    %parse = (); #?
  }

  foreach my $from ('address1', 'address2') {
    foreach my $parse ( keys %parse ) {
      my $value = $self->get($prefix.$from);
      if ( $value =~ s/(^|\W+)$parse\W+(\w+)\W*$//i ) {
        $self->set($prefix.'location_type', $parse{$parse});
        $self->set($prefix.'location_number', $2);
        $self->set($prefix.$from, $value);
        return '';
      }
    }
  }

  #nothing matched, no changes
  $self->get($prefix.'address2')
    ? "Can't parse unit type and number from ${prefix}address2"
    : '';
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

