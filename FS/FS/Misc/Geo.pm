package FS::Misc::Geo;

use strict;
use base qw( Exporter );
use vars qw( $DEBUG @EXPORT_OK );
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common qw( GET POST );
use HTML::TokeParser;
use Data::Dumper;

$DEBUG = 1;

@EXPORT_OK = qw( get_censustract );

=head1 NAME

FS::Misc::Geo - routines to fetch geographic information

=head1 FUNCTIONS

=over 4

=item censustract LOCATION YEAR

Given a location hash (see L<FS::location_Mixin>) and a census map year,
returns a census tract code (consisting of state, county, and tract 
codes) or an error message.

=cut

sub get_censustract {
  my $location = shift;
  my $year  = shift;

  warn Dumper($location, $year) if $DEBUG;

  my $url='http://www.ffiec.gov/Geocode/default.aspx';

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

      $year ||= '2011';
      #ugh  workaround a mess at ffiec
      $year = " $year" if $year ne '2011';
      my @ffiec_args = (
        __VIEWSTATE => $viewstate,
        __EVENTVALIDATION => $eventvalidation,
        ddlbYear    => $year,
        ddlbYear    => '2011', #' 2009',
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

        $error = "No census tract found" unless $return->{tractcode};
        $return->{tractcode} .= ' '
          unless $error || $JSON::VERSION >= 2; #broken JSON 1 workaround

      } #unless ($res->code  eq '200')

    } #unless ($viewstate)

  } #unless ($res->code  eq '200')

  return "FFIEC Geocoding error: $error" if $error;

  $return->{'statecode'} .  $return->{'countycode'} .  $return->{'tractcode'};
}

1;
