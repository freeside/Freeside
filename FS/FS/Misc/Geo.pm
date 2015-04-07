package FS::Misc::Geo;

use strict;
use base qw( Exporter );
use vars qw( $DEBUG @EXPORT_OK $conf );
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common qw( GET POST );
use HTML::TokeParser;
use JSON;
use URI::Escape 3.31;
use Data::Dumper;
use FS::Conf;
use Locale::Country;

FS::UID->install_callback( sub {
  $conf = new FS::Conf;
} );

$DEBUG = 1;

@EXPORT_OK = qw( get_district );

=head1 NAME

FS::Misc::Geo - routines to fetch geographic information

=head1 CLASS METHODS

=over 4

=item get_censustract_ffiec LOCATION YEAR

Given a location hash (see L<FS::location_Mixin>) and a census map year,
returns a census tract code (consisting of state, county, and tract 
codes) or an error message.

=cut

sub get_censustract_ffiec {
  my $class = shift;
  my $location = shift;
  my $year  = shift;
  $year ||= 2012;

  if ( length($location->{country}) and uc($location->{country}) ne 'US' ) {
    return '';
  }

  warn Dumper($location, $year) if $DEBUG;

  # the old FFIEC geocoding service was shut down December 1, 2014.
  # welcome to the future.
  my $url = 'https://geomap.ffiec.gov/FFIECGeocMap/GeocodeMap1.aspx/GetGeocodeData';
  # build the single-line query
  my $single_line = join(', ', $location->{address1},
                               $location->{city},
                               $location->{state}
                        );
  my $hashref = { sSingleLine => $single_line, iCensusYear => $year };
  my $request = POST( $url,
    'Content-Type' => 'application/json; charset=utf-8',
    'Accept' => 'application/json',
    'Content' => encode_json($hashref)
  );

  my $ua = new LWP::UserAgent;
  my $res = $ua->request( $request );

  warn $res->as_string
    if $DEBUG > 2;

  if (!$res->is_success) {

    die "Census tract lookup error: ".$res->message;

  }

  local $@;
  my $content = eval { decode_json($res->content) };
  die "Census tract JSON error: $@\n" if $@;

  if ( !exists $content->{d}->{sStatus} ) {
    die "Census tract response is missing a status indicator.\nThis is an FFIEC problem.\n";
  }
  if ( $content->{d}->{sStatus} eq 'Y' ) {
    # success
    # this also contains the (partial) standardized address, correct zip 
    # code, coordinates, etc., and we could get all of them, but right now
    # we only want the census tract
    my $tract = join('', $content->{d}->{sStateCode},
                         $content->{d}->{sCountyCode},
                         $content->{d}->{sTractCode});
    return $tract;

  } else {

    my $error = $content->{d}->{sMsg}
            ||  'FFIEC lookup failed, but with no status message.';
    die "$error\n";

  }
}

#sub get_district_methods {
#  ''         => '',
#  'wa_sales' => 'Washington sales tax',
#};

=item get_district LOCATION METHOD

For the location hash in LOCATION, using lookup method METHOD, fetch
tax district information.  Currently the only available method is 
'wa_sales' (the Washington Department of Revenue sales tax lookup).

Returns a hash reference containing the following fields:

- district
- tax (percentage)
- taxname
- exempt_amount (currently zero)
- city, county, state, country (from 

The intent is that you can assign this to an L<FS::cust_main_county> 
object and insert it if there's not yet a tax rate defined for that 
district.

get_district will die on error.

=over 4

=cut

sub get_district {
  no strict 'refs';
  my $location = shift;
  my $method = shift or return '';
  warn Dumper($location, $method) if $DEBUG;
  &$method($location);
}

sub wa_sales {
  my $location = shift;
  my $error = '';
  return '' if $location->{state} ne 'WA';

  my $return = { %$location };
  $return->{'exempt_amount'} = 0.00;

  my $url = 'http://webgis2.dor.wa.gov/TaxRateLookup_AGS/TaxReport.aspx';
  my $ua = new LWP::UserAgent;

  my $delim = '<|>'; # yes, <|>
  my $year  = (localtime)[5] + 1900;
  my $month = (localtime)[4] + 1;
  my @zip = split('-', $location->{zip});

  my @args = (
    'TaxType=S',  #sales; 'P' = property
    'Src=0',      #does something complicated
    'TAXABLE=',
    'Addr='.uri_escape($location->{address1}),
    'City='.uri_escape($location->{city}),
    'Zip='.$zip[0],
    'Zip1='.($zip[1] || ''), #optional
    'Year='.$year,
    'SYear='.$year,
    'Month='.$month,
    'EMon='.$month,
  );
  
  my $query_string = join($delim, @args );
  $url .= "?$query_string";
  warn "\nrequest:  $url\n\n" if $DEBUG > 1;

  my $res = $ua->request( GET( "$url?$query_string" ) );

  warn $res->as_string
  if $DEBUG > 2;

  if ($res->code ne '200') {
    $error = $res->message;
  }

  my $content = $res->content;
  my $p = new HTML::TokeParser \$content;
  my $js = '';
  while ( my $t = $p->get_tag('script') ) {
    my $u = $p->get_token; #either enclosed text or the </script> tag
    if ( $u->[0] eq 'T' and $u->[1] =~ /tblSales/ ) {
      $js = $u->[1];
      last;
    }
  }
  if ( $js ) { #found it
    # strip down to the quoted string, which contains escaped single quotes.
    $js =~ s/.*\('tblSales'\);c.innerHTML='//s;
    $js =~ s/(?<!\\)'.*//s; # (?<!\\) means "not preceded by a backslash"
    warn "\n\n  innerHTML:\n$js\n\n" if $DEBUG > 2;

    $p = new HTML::TokeParser \$js;
    TD: while ( my $td = $p->get_tag('td') ) {
      while ( my $u = $p->get_token ) {
        next TD if $u->[0] eq 'E' and $u->[1] eq 'td';
        next if $u->[0] ne 'T'; # skip non-text
        my $text = $u->[1];

        if ( lc($text) eq 'location code' ) {
          $p->get_tag('td'); # skip to the next column
          undef $u;
          $u = $p->get_token until $u->[0] eq 'T'; # and then skip non-text
          $return->{'district'} = $u->[1];
        }
        elsif ( lc($text) eq 'total tax rate' ) {
          $p->get_tag('td');
          undef $u;
          $u = $p->get_token until $u->[0] eq 'T';
          $return->{'tax'} = $u->[1];
        }
      } # get_token
    } # TD

    # just to make sure
    if ( $return->{'district'} =~ /^\d+$/ and $return->{'tax'} =~ /^.\d+$/ ) {
      $return->{'tax'} *= 100; #percentage
      warn Dumper($return) if $DEBUG > 1;
      return $return;
    }
    else {
      $error = 'district code/tax rate not found';
    }
  }
  else {
    $error = "failed to parse document";
  }

  die "WA tax district lookup error: $error";
}

###### USPS Standardization ######

sub standardize_usps {
  my $class = shift;

  eval "use Business::US::USPS::WebTools::AddressStandardization";
  die $@ if $@;

  my $location = shift;
  if ( $location->{country} ne 'US' ) {
    # soft failure
    warn "standardize_usps not for use in country ".$location->{country}."\n";
    $location->{addr_clean} = '';
    return $location;
  }
  my $userid   = $conf->config('usps_webtools-userid');
  my $password = $conf->config('usps_webtools-password');
  my $verifier = Business::US::USPS::WebTools::AddressStandardization->new( {
      UserID => $userid,
      Password => $password,
      Testing => 0,
  } ) or die "error starting USPS WebTools\n";

  my($zip5, $zip4) = split('-',$location->{'zip'});

  my %usps_args = (
    FirmName => $location->{company},
    Address2 => $location->{address1},
    Address1 => $location->{address2},
    City     => $location->{city},
    State    => $location->{state},
    Zip5     => $zip5,
    Zip4     => $zip4,
  );
  warn join('', map "$_: $usps_args{$_}\n", keys %usps_args )
    if $DEBUG > 1;

  my $hash = $verifier->verify_address( %usps_args );

  warn $verifier->response
    if $DEBUG > 1;

  die "USPS WebTools error: ".$verifier->{error}{description} ."\n"
    if $verifier->is_error;

  my $zip = $hash->{Zip5};
  $zip .= '-' . $hash->{Zip4} if $hash->{Zip4} =~ /\d/;

  { company   => $hash->{FirmName},
    address1  => $hash->{Address2},
    address2  => $hash->{Address1},
    city      => $hash->{City},
    state     => $hash->{State},
    zip       => $zip,
    country   => 'US',
    addr_clean=> 'Y' }
}

###### U.S. Census Bureau ######

sub standardize_uscensus {
  my $self = shift;
  my $location = shift;

  eval "use Geo::USCensus::Geocoding";
  die $@ if $@;

  if ( $location->{country} ne 'US' ) {
    # soft failure
    warn "standardize_uscensus not for use in country ".$location->{country}."\n";
    $location->{addr_clean} = '';
    return $location;
  }

  my $request = {
    street  => $location->{address1},
    city    => $location->{city},
    state   => $location->{state},
    zip     => $location->{zip},
    debug   => ($DEBUG || 0),
  };

  my $result = Geo::USCensus::Geocoding->query($request);
  if ( $result->is_match ) {
    # unfortunately we get the address back as a single line
    if ($result->address =~ /^(.*), (.*), ([A-Z]{2}), (\d{5}.*)$/) {
      return +{
        address1    => $1,
        city        => $2,
        state       => $3,
        zip         => $4,
        address2    => uc($location->{address2}),
        latitude    => $result->latitude,
        longitude   => $result->longitude,
        censustract => $result->censustract,
      };
    } else {
      die "Geocoding returned '".$result->address."', which does not seem to be a valid address.\n";
    }
  } elsif ( $result->match_level eq 'Tie' ) {
    die "Geocoding was not able to identify a unique matching address.\n";
  } elsif ( $result->match_level ) {
    die "Geocoding did not find a matching address.\n";
  } else {
    warn Dumper($result) if $DEBUG;
    die $result->error_message;
  }
}

####### EZLOCATE (obsolete) #######

my %ezlocate_error = ( # USA_Geo_002 documentation
  10  => 'State not found',
  11  => 'City not found',
  12  => 'Invalid street address',
  14  => 'Street name not found',
  15  => 'Address range does not exist',
  16  => 'Ambiguous address',
  17  => 'Intersection not found', #unused?
);

sub standardize_ezlocate {
  my $self = shift;
  my $location = shift;
  my $class;
  #if ( $location->{country} eq 'US' ) {
  #  $class = 'USA_Geo_004Tool';
  #}
  #elsif ( $location->{country} eq 'CA' ) {
  #  $class = 'CAN_Geo_001Tool';
  #}
  #else { # shouldn't be a fatal error, just pass through unverified address
  #  warn "standardize_teleatlas: address lookup in '".$location->{country}.
  #       "' not available\n";
  #  return $location;
  #}
  #my $path = $conf->config('teleatlas-path') || '';
  #local @INC = (@INC, $path);
  #eval "use $class;";
  #if ( $@ ) {
  #  die "Loading $class failed:\n$@".
  #      "\nMake sure the TeleAtlas Perl SDK is installed correctly.\n";
  #}

  $class = 'Geo::EZLocate'; # use our own library
  eval "use $class 0.02"; #Geo::EZLocate 0.02 for error handling
  die $@ if $@;

  my $userid = $conf->config('ezlocate-userid')
    or die "no ezlocate-userid configured\n";
  my $password = $conf->config('ezlocate-password')
    or die "no ezlocate-password configured\n";
  
  my $tool = $class->new($userid, $password);
  my $match = $tool->findAddress(
    $location->{address1},
    $location->{city},
    $location->{state},
    $location->{zip}, #12345-6789 format is allowed
  );
  warn "ezlocate returned match:\n".Dumper($match) if $DEBUG > 1;
  # error handling - B codes indicate success
  die $ezlocate_error{$match->{MAT_STAT}}."\n"
    unless $match->{MAT_STAT} =~ /^B\d$/;

  my %result = (
    address1    => $match->{MAT_ADDR},
    address2    => $location->{address2},
    city        => $match->{MAT_CITY},
    state       => $match->{MAT_ST},
    country     => $location->{country},
    zip         => $match->{MAT_ZIP},
    latitude    => $match->{MAT_LAT},
    longitude   => $match->{MAT_LON},
    censustract => $match->{FIPS_ST}.$match->{FIPS_CTY}.
                   sprintf('%07.2f',$match->{CEN_TRCT}),
    addr_clean  => 'Y',
  );
  if ( $match->{STD_ADDR} ) {
    # then they have a postal standardized address for us
    %result = ( %result,
      address1    => $match->{STD_ADDR},
      address2    => $location->{address2},
      city        => $match->{STD_CITY},
      state       => $match->{STD_ST},
      zip         => $match->{STD_ZIP}.'-'.$match->{STD_P4},
    );
  }

  \%result;
}

sub _tomtom_query { # helper method for the below
  my %args = @_;
  my $result = Geo::TomTom::Geocoding->query(%args);
  die "TomTom geocoding error: ".$result->message."\n"
    unless ( $result->is_success );
  my ($match) = $result->locations;
  my $type = $match->{type};
  # match levels below "intersection" should not be considered clean
  my $clean = ($type eq 'addresspoint'  ||
               $type eq 'poi'           ||
               $type eq 'house'         ||
               $type eq 'intersection'
              ) ? 'Y' : '';
  warn "tomtom returned $type match\n" if $DEBUG;
  warn Dumper($match) if $DEBUG > 1;
  ($match, $clean);
}

sub standardize_tomtom {
  # post-2013 TomTom API
  # much better, but incompatible with ezlocate
  my $self = shift;
  my $location = shift;
  eval "use Geo::TomTom::Geocoding; use Geo::StreetAddress::US";
  die $@ if $@;

  my $key = $conf->config('tomtom-userid')
    or die "no tomtom-userid configured\n";

  my $country = code2country($location->{country});
  my ($address1, $address2) = ($location->{address1}, $location->{address2});
  my $subloc = '';

  # trim whitespace
  $address1 =~ s/^\s+//;
  $address1 =~ s/\s+$//;
  $address2 =~ s/^\s+//;
  $address2 =~ s/\s+$//;

  # try to fix some cases of the address fields being switched
  if ( $address2 =~ /^\d/ and $address1 !~ /^\d/ ) {
    $address2 = $address1;
    $address1 = $location->{address2};
  }
  # parse sublocation part (unit/suite/apartment...) and clean up 
  # non-sublocation address2
  ($subloc, $address2) =
    subloc_address2($address1, $address2, $location->{country});
  # ask TomTom to standardize address1:
  my %args = (
    key => $key,
    T   => $address1,
    L   => $location->{city},
    AA  => $location->{state},
    PC  => $location->{zip},
    CC  => country2code($country, LOCALE_CODE_ALPHA_3),
  );

  my ($match, $clean) = _tomtom_query(%args);

  if (!$match or !$clean) {
    # Then try cleaning up the input; TomTom is picky about junk in the 
    # address.  Any of these can still be a clean match.
    my $h = Geo::StreetAddress::US->parse_location($address1);
    # First conservatively:
    if ( $h->{sec_unit_type} ) {
      my $strip = '\s+' . $h->{sec_unit_type};
      $strip .= '\s*' . $h->{sec_unit_num} if $h->{sec_unit_num};
      $strip .= '$';
      $args{T} =~ s/$strip//;
      ($match, $clean) = _tomtom_query(%args);
    }
    if ( !$match or !$clean ) {
      # Then more aggressively:
      $args{T} = uc( join(' ', @$h{'number', 'street', 'type'}) );
      ($match, $clean) = _tomtom_query(%args);
    }
  }

  if ( !$match or !$clean ) { # partial matches are not useful
    die "Address not found\n";
  }
  my $tract = '';
  if ( defined $match->{censusTract} ) {
    $tract = $match->{censusStateCode}. $match->{censusFipsCountyCode}.
             join('.', $match->{censusTract} =~ /(....)(..)/);
  }
  $address1 = '';
  $address1 = $match->{houseNumber} . ' ' if length($match->{houseNumber});
  $address1 .= $match->{street} if $match->{street};
  $address1 .= ' '.$subloc if $subloc;
  $address1 = uc($address1); # USPS standards

  return +{
    address1    => $address1,
    address2    => $address2,
    city        => uc($match->{city}),
    state       => uc($location->{state}),
    country     => uc($location->{country}),
    zip         => ($match->{standardPostalCode} || $match->{postcode}),
    latitude    => $match->{latitude},
    longitude   => $match->{longitude},
    censustract => $tract,
    addr_clean  => $clean,
  };
}

=iten subloc_address2 ADDRESS1, ADDRESS2, COUNTRY

Given 'address1' and 'address2' strings, extract the sublocation part 
(from either one) and return it.  If the sublocation was found in ADDRESS1,
also return ADDRESS2 (cleaned up for postal standards) as it's assumed to
contain something relevant.

=cut

my %subloc_forms = (
  # Postal Addressing Standards, Appendix C
  # (plus correction of "hanger" to "hangar")
  US => {qw(
    APARTMENT     APT
    BASEMENT      BSMT
    BUILDING      BLDG
    DEPARTMENT    DEPT
    FLOOR         FL
    FRONT         FRNT
    HANGAR        HNGR
    HANGER        HNGR
    KEY           KEY
    LOBBY         LBBY
    LOT           LOT
    LOWER         LOWR
    OFFICE        OFC
    PENTHOUSE     PH
    PIER          PIER
    REAR          REAR
    ROOM          RM
    SIDE          SIDE
    SLIP          SLIP
    SPACE         SPC
    STOP          STOP
    SUITE         STE
    TRAILER       TRLR
    UNIT          UNIT
    UPPER         UPPR
  )},
  # Canada Post Addressing Guidelines 4.3
  CA => {qw(
    APARTMENT     APT
    APPARTEMENT   APP
    BUREAU        BUREAU
    SUITE         SUITE
    UNIT          UNIT
    UNITÉ         UNITÉ
  )},
);
 
sub subloc_address2 {
  # Some things seen in the address2 field:
  # Whitespace
  # The complete address (with address1 containing part of the company name, 
  # or an ATTN or DBA line, or P.O. Box, or department name, or building/suite
  # number, etc.)

  # try to parse sublocation parts from address1; if they are present we'll
  # append them back to address1 after standardizing
  my $subloc = '';
  my ($addr1, $addr2, $country) = map uc, @_;
  my $dict = $subloc_forms{$country} or return('', $addr2);
  
  my $found_in = 0; # which address is the sublocation
  my $h;
  foreach my $string (
    # patterns to try to parse
    $addr1,
    "$addr1 Nullcity, CA"
  ) {
    $h = Geo::StreetAddress::US->parse_location($addr1);
    last if exists($h->{sec_unit_type});
  }
  if (exists($h->{sec_unit_type})) {
    $found_in = 1
  } else {
    foreach my $string (
      # more patterns
      $addr2,
      "$addr1, $addr2",
      "$addr1, $addr2 Nullcity, CA"
    ) {
      $h = Geo::StreetAddress::US->parse_location("$addr1, $addr2");
      last if exists($h->{sec_unit_type});
    }
    if (exists($h->{sec_unit_type})) {
      $found_in = 2;
    }
  }
  if ( $found_in ) {
    $subloc = $h->{sec_unit_type};
    # special case: do not combine P.O. box sublocs with address1
    if ( $h->{sec_unit_type} =~ /^P *O *BOX/i ) {
      if ( $found_in == 2 ) {
        $addr2 = "PO BOX ".$h->{sec_unit_num};
      } # else it's in addr1, and leave it alone
      return ('', $addr2);
    } elsif ( exists($dict->{$subloc}) ) {
      # substitute the official abbreviation
      $subloc = $dict->{$subloc};
    }
    $subloc .= ' ' . $h->{sec_unit_num} if length($h->{sec_unit_num});
  } # otherwise $subloc = ''

  if ( $found_in == 2 ) {
    # address2 should be fully combined into address1
    return ($subloc, '');
  }
  # else address2 is not the canonical sublocation, but do our best to 
  # clean it up
  #
  # protect this
  $addr2 =~ s/#\s*(\d)/NUMBER$1/; # /g?
  my @words;
  # remove all punctuation and spaces
  foreach my $w (split(/\W+/, $addr2)) {
    if ( exists($dict->{$w}) ) {
      push @words, $dict->{$w};
    } else {
      push @words, $w;
    }
    my $result = join(' ', @words);
    # correct spacing of pound sign + number
    $result =~ s/NUMBER(\d)/# $1/;
    warn "normalizing '$addr2' to '$result'\n" if $DEBUG > 1;
    $addr2 = $result;
  }
  $addr2 = '' if $addr2 eq $subloc; # if it was entered redundantly
  ($subloc, $addr2);
}

sub standardize_melissa {
  my $class = shift;
  my $location = shift;

  local $@;
  eval "use Geo::Melissa::WebSmart";
  die $@ if $@;

  my $id = $conf->config('melissa-userid')
    or die "no melissa-userid configured\n";
  my $geocode = $conf->exists('melissa-enable_geocoding') ? 1 : 0;

  my $request = {
    id      => $id,
    a1      => $location->{address1},
    a2      => $location->{address2},
    city    => $location->{city},
    state   => $location->{state},
    ctry    => $location->{country},
    zip     => $location->{zip},
    geocode => $geocode,
  };
  my $result = Geo::Melissa::WebSmart->query($request);
  if ( $result->code =~ /AS01/ ) { # always present on success
    my $addr = $result->address;
    warn Dumper $addr if $DEBUG > 1;
    my $out = {
      address1    => $addr->{Address1},
      address2    => $addr->{Address2},
      city        => $addr->{City}->{Name},
      state       => $addr->{State}->{Abbreviation},
      country     => $addr->{Country}->{Abbreviation},
      zip         => $addr->{Zip},
      latitude    => $addr->{Latitude},
      longitude   => $addr->{Longitude},
      addr_clean  => 'Y',
    };
    if ( $addr->{Census}->{Tract} ) {
      my $censustract = $addr->{County}->{Fips} . $addr->{Census}->{Tract};
      # insert decimal point two digits from the end
      $censustract =~ s/(\d\d)$/\.$1/;
      $out->{censustract} = $censustract;
      $out->{censusyear} = $conf->config('census_year');
    }
    # we could do a lot more nuanced reporting of the warning/status codes,
    # but the UI doesn't support that yet.
    return $out;
  } else {
    die $result->status_message;
  }
}

=back

=cut

1;
