package FS::geocode_Mixin;

use strict;
use vars qw( $DEBUG $me );
use Carp;
use Locale::Country ();
use Geo::Coder::Googlev3; #compile time for now, until others are supported
use FS::Record qw( qsearchs qsearch );
use FS::Conf;
use FS::cust_pkg;
use FS::cust_location;
use FS::cust_tax_location;
use FS::part_pkg;
use FS::part_pkg_taxclass;

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

  my $lt = $self->get($prefix.'location_type');
  if ( $lt ) {
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

    $line .= ' '.&$escape( $location_type{$lt} || $lt );
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
  $line .= $separator. &$escape($self->country_full)
    if $self->country ne $cydefault;

  $line;
}

=item country_full

Returns the full country name.

=cut

sub country_full {
  my $self = shift;
  $self->code2country($self->get('country'));
}

sub code2country {
  my( $self, $country ) = @_;

  #a hash?  not expecting an explosion of business from unrecognized countries..
  return 'KKTC' if $country eq 'XC';
                                           
  Locale::Country::code2country($country);
}

=item set_coord

Look up the coordinates of the location using (currently) the Google Maps
API and set the 'latitude' and 'longitude' fields accordingly.

=cut

sub set_coord {
  my $self = shift;

  #my $module = FS::Conf->new->config('geocode_module') || 'Geo::Coder::Googlev3';

  my $geocoder = Geo::Coder::Googlev3->new;

  my $location = eval {
    $geocoder->geocode( location =>
      $self->get('address1'). ','.
      ( $self->get('address2') ? $self->get('address2').',' : '' ).
      $self->get('city'). ','.
      $self->get('state'). ','.
      $self->country_full
    );
  };
  if ( $@ ) {
    warn "geocoding error: $@\n";
    return;
  }

  my $geo_loc = $location->{'geometry'}{'location'} or return;
  if ( $geo_loc->{'lat'} && $geo_loc->{'lng'} ) {
    $self->set('latitude',  $geo_loc->{'lat'} );
    $self->set('longitude', $geo_loc->{'lng'} );
    $self->set('coord_auto', 'Y');
  }

}

=item geocode DATA_VENDOR

Returns a value for the customer location as encoded by DATA_VENDOR.
Currently this only makes sense for "CCH" as DATA_VENDOR.

=cut

sub geocode {
  my ($self, $data_vendor) = (shift, shift);  #always cch for now

  my $geocode = $self->get('geocode');  #XXX only one data_vendor for geocode
  return $geocode if $geocode;

  if ( $self->isa('FS::cust_main') ) {
    warn "WARNING: FS::cust_main->geocode deprecated";

    # do the best we can
    my $m = FS::Conf->new->exists('tax-ship_address') ? 'ship_location'
                                                      : 'bill_location';
    my $location = $self->$m or return '';
    return $location->geocode($data_vendor);
  }

  my($zip,$plus4) = split /-/, $self->get('zip')
    if $self->country eq 'US';

  $zip ||= '';
  $plus4 ||= '';
  #CCH specific location stuff
  my $extra_sql = $plus4 ? "AND plus4lo <= '$plus4' AND plus4hi >= '$plus4'"
                         : '';

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

  warn "WARNING: customer ". $self->custnum.
       ": multiple locations for zip ". $self->get("zip").
       "; using arbitrary geocode $geocode\n"
    if scalar(@cust_tax_location) > 1;

  $geocode;
}

=item process_district_update CLASS ID

Queueable function to update the tax district code using the selected method 
(config 'tax_district_method').  CLASS is either 'FS::cust_main' or 
'FS::cust_location'; ID is the key in one of those tables.

=cut

# this is run from the job queue so I'm not transactionizing it.

sub process_district_update {
  my $class = shift;
  my $id = shift;
  my $log = FS::Log->new('FS::cust_location::process_district_update');

  eval "use FS::Misc::Geo qw(get_district); use FS::Conf; use $class;";
  die $@ if $@;
  die "$class has no location data" if !$class->can('location_hash');

  my $error;
  my $conf = FS::Conf->new;
  my $method = $conf->config('tax_district_method')
    or return; #nothing to do if null
  my $self = $class->by_key($id) or die "object $id not found";
  return if $self->disabled;

  # dies on error, fine
  my $tax_info = get_district({ $self->location_hash }, $method);
  return unless $tax_info;

  if ($self->district ne $tax_info->{'district'}) {
    $self->set('district', $tax_info->{'district'} );
    $error = $self->replace;
    die $error if $error;
  }

  my %hash = map { $_ => uc( $tax_info->{$_} ) } 
    qw( district city county state country );
  $hash{'source'} = $method; # apply the update only to taxes we maintain

  my @classes = FS::part_pkg_taxclass->taxclass_names;
  my $taxname = $conf->config('tax_district_taxname');
  # there must be exactly one cust_main_county for each district+taxclass.
  # do NOT exclude taxes that are zero.

  # mutex here so that concurrent queue jobs can't make duplicates.
  FS::cust_main_county->lock_table;
  foreach my $taxclass (@classes) {
    my @existing = qsearch('cust_main_county', {
      %hash,
      'taxclass' => $taxclass
    });

    if ( scalar(@existing) == 0 ) {

      # then create one with the assigned tax name, and the tax rate from
      # the lookup.
      my $new = new FS::cust_main_county({
        %hash,
        'taxclass'      => $taxclass,
        'taxname'       => $taxname,
        'tax'           => $tax_info->{tax},
        'exempt_amount' => 0,
      });
      $log->info("creating tax rate for district ".$tax_info->{'district'});
      $error = $new->insert;

    } else {

      my $to_update = $existing[0];
      # if there's somehow more than one, find the best candidate to be
      # updated:
      # - prefer tax > 0 over tax = 0 (leave disabled records disabled)
      # - then, prefer taxname = the designated taxname
      if ( scalar(@existing) > 1 ) {
        $log->warning("tax district ".$tax_info->{district}." has multiple $method taxes.");
        foreach (@existing) {
          if ( $to_update->tax == 0 ) {
            if ( $_->tax > 0 and $to_update->tax == 0 ) {
              $to_update = $_;
            } elsif ( $_->tax == 0 and $to_update->tax > 0 ) {
              next;
            } elsif ( $_->taxname eq $taxname and $to_update->tax ne $taxname ) {
              $to_update = $_;
            }
          }
        }
        # don't remove the excess records here; upgrade does that.
      }
      my $taxnum = $to_update->taxnum;
      if ( $to_update->tax == 0 ) {
        $log->debug("tax#$taxnum is set to zero; not updating.");
      } elsif ( $to_update->tax == $tax_info->{tax} ) {
        # do nothing, no need to update
      } else {
        $to_update->set('tax', $tax_info->{tax});
        $log->info("updating tax#$taxnum with new rate ($tax_info->{tax}).");
        $error = $to_update->replace;
      }
    }

    die $error if $error;

  } # foreach $taxclass

  return;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

