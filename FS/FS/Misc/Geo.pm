package FS::Misc::Geo;

use strict;
use base qw( Exporter );
use vars qw( $DEBUG @EXPORT_OK );
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common qw( GET POST );
use HTML::TokeParser;
use URI::Escape;
use Data::Dumper;

$DEBUG = 0;

@EXPORT_OK = qw( get_censustract get_district );

=head1 NAME

FS::Misc::Geo - routines to fetch geographic information

=head1 FUNCTIONS

=over 4

=item get_censustract LOCATION YEAR

Given a location hash (see L<FS::location_Mixin>) and a census map year,
returns a census tract code (consisting of state, county, and tract 
codes) or an error message.

=cut

sub get_censustract {
  my $location = shift;
  my $year  = shift;

  warn Dumper($location, $year) if $DEBUG;

  my $url = 'http://www.ffiec.gov/Geocode/default.aspx';

  my $return = {};
  my $error = '';

  my $ua = new LWP::UserAgent;
  my $res = $ua->request( GET( $url ) );

  warn $res->as_string
    if $DEBUG > 1;

  unless ($res->code  eq '200') {

    $error = $res->message;

  } else {

    my $content = $res->content;
    my $p = new HTML::TokeParser \$content;
    my $viewstate;
    my $eventvalidation;
    while (my $token = $p->get_tag('input') ) {
      if ($token->[1]->{name} eq '__VIEWSTATE') {
        $viewstate = $token->[1]->{value};
      }
      if ($token->[1]->{name} eq '__EVENTVALIDATION') {
        $eventvalidation = $token->[1]->{value};
      }
      last if $viewstate && $eventvalidation;
    }

    unless ($viewstate && $eventvalidation ) {

      $error = "either no __VIEWSTATE or __EVENTVALIDATION found";

    } else {

      my($zip5, $zip4) = split('-',$location->{zip});

      $year ||= '2011'; #2012 per http://transition.fcc.gov/form477/techfaqs.html soon/now?
      my @ffiec_args = (
        __VIEWSTATE => $viewstate,
        __EVENTVALIDATION => $eventvalidation,
        ddlbYear    => $year,
        txtAddress  => $location->{address1},
        txtCity     => $location->{city},  
        ddlbState   => $location->{state},
        txtZipCode  => $zip5,
        btnSearch   => 'Search',
      );
      warn join("\n", @ffiec_args )
        if $DEBUG;

      push @{ $ua->requests_redirectable }, 'POST';
      $res = $ua->request( POST( $url, \@ffiec_args ) );
      warn $res->as_string
        if $DEBUG > 1;

      unless ($res->code  eq '200') {

        $error = $res->message;

      } else {

        my @id = qw( MSACode StateCode CountyCode TractCode );
        $content = $res->content;
        warn $res->content if $DEBUG > 1;
        $p = new HTML::TokeParser \$content;
        my $prefix = 'UcGeoResult11_lb';
        my $compare =
          sub { my $t=shift; scalar( grep { lc($t) eq lc("$prefix$_")} @id ) };

        while (my $token = $p->get_tag('span') ) {
          next unless ( $token->[1]->{id} && &$compare( $token->[1]->{id} ) );
          $token->[1]->{id} =~ /^$prefix(\w+)$/;
          $return->{lc($1)} = $p->get_trimmed_text("/span");
        }

        unless ( $return->{tractcode} ) {
          warn "$error: $content ". Dumper($return) if $DEBUG;
          $error = "No census tract found";
        }
        $return->{tractcode} .= ' '
          unless $error || $JSON::VERSION >= 2; #broken JSON 1 workaround

      } #unless ($res->code  eq '200')

    } #unless ($viewstate)

  } #unless ($res->code  eq '200')

  return "FFIEC Geocoding error: $error" if $error;

  $return->{'statecode'} .  $return->{'countycode'} .  $return->{'tractcode'};
}

sub get_district_methods {
  ''         => '',
  'wa_sales' => 'Washington sales tax',
};

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
  warn "\nrequest:  $url\n\n" if $DEBUG;

  my $res = $ua->request( GET( "$url?$query_string" ) );

  warn $res->as_string
  if $DEBUG > 1;

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
      warn Dumper($return) if $DEBUG;
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

=back

=cut


1;
