#!/usr/bin/perl -Tw
#
# this will break when megapop changes the URL or format of their listing page.
# that's stupid.  perhaps they can provide a machine-readable listing?

use strict;
use LWP::UserAgent;
use FS::UID qw(adminsuidsetup);
use FS::svc_acct_pop;

my $url = "http://www.megapop.com/location.htm";

my $user = shift or die &usage;
adminsuidsetup($user);

my %state2usps = &state2usps;
$state2usps{'WASHINGTON STATE'} = 'WA'; #megapop's on crack
$state2usps{'CANADA'} = 'CANADA'; #freeside's on crack

my $ua = new LWP::UserAgent;
my $request = new HTTP::Request('GET', $url);
my $response = $ua->request($request);
die $response->error_as_HTML unless $response->is_success;
my $line;
my $usps = '';
foreach $line ( split("\n", $response->content) ) {
  if ( $line =~ /\W(\w[\w\s]*\w)\s+LOCATIONS/i ) {
    $usps = $state2usps{uc($1)}
      or warn "warning: unknown state $1\n";
  } elsif ( $line =~ /(\d{3})\-(\d{3})\-(\d{4})\s+(\w[\w\s]*\w)/ ) {
    print "$1 $2 $3 $4 $usps\n";
    my $svc_acct_pop = new FS::svc_acct_pop ( {
      'city' => $4,
      'state' => $usps,
      'ac' => $1,
      'exch' => $2,
    } );
    my $error = $svc_acct_pop->insert;
    die $error if $error;
  }
}

sub usage {
  die "Usage:\n  $0 user\n";
}

sub state2usps{ (
  'ALABAMA' => 'AL',
  'ALASKA' => 'AK',
  'AMERICAN SAMOA' => 'AS',
  'ARIZONA' => 'AZ',
  'ARKANSAS' => 'AR',
  'CALIFORNIA' => 'CA',
  'COLORADO' => 'CO',
  'CONNECTICUT' => 'CT',
  'DELAWARE' => 'DE',
  'DISTRICT OF COLUMBIA' => 'DC',
  'FEDERATED STATES OF MICRONESIA' => 'FM',
  'FLORIDA' => 'FL',
  'GEORGIA' => 'GA',
  'GUAM' => 'GU',
  'HAWAII' => 'HI',
  'IDAHO' => 'ID',
  'ILLINOIS' => 'IL',
  'INDIANA' => 'IN',
  'IOWA' => 'IA',
  'KANSAS' => 'KS',
  'KENTUCKY' => 'KY',
  'LOUISIANA' => 'LA',
  'MAINE' => 'ME',
  'MARSHALL ISLANDS' => 'MH',
  'MARYLAND' => 'MD',
  'MASSACHUSETTS' => 'MA',
  'MICHIGAN' => 'MI',
  'MINNESOTA' => 'MN',
  'MISSISSIPPI' => 'MS',
  'MISSOURI' => 'MO',
  'MONTANA' => 'MT',
  'NEBRASKA' => 'NE',
  'NEVADA' => 'NV',
  'NEW HAMPSHIRE' => 'NH',
  'NEW JERSEY' => 'NJ',
  'NEW MEXICO' => 'NM',
  'NEW YORK' => 'NY',
  'NORTH CAROLINA' => 'NC',
  'NORTH DAKOTA' => 'ND',
  'NORTHERN MARIANA ISLANDS' => 'MP',
  'OHIO' => 'OH',
  'OKLAHOMA' => 'OK',
  'OREGON' => 'OR',
  'PALAU' => 'PW',
  'PENNSYLVANIA' => 'PA',
  'PUERTO RICO' => 'PR',
  'RHODE ISLAND' => 'RI',
  'SOUTH CAROLINA' => 'SC',
  'SOUTH DAKOTA' => 'SD',
  'TENNESSEE' => 'TN',
  'TEXAS' => 'TX',
  'UTAH' => 'UT',
  'VERMONT' => 'VT',
  'VIRGIN ISLANDS' => 'VI',
  'VIRGINIA' => 'VA',
  'WASHINGTON' => 'WA',
  'WEST VIRGINIA' => 'WV',
  'WISCONSIN' => 'WI',
  'WYOMING' => 'WY',
  'ARMED FORCES AFRICA' => 'AE',
  'ARMED FORCES AMERICAS' => 'AA',
  'ARMED FORCES CANADA' => 'AE',
  'ARMED FORCES EUROPE' => 'AE',
  'ARMED FORCES MIDDLE EAST' => 'AE',
  'ARMED FORCES PACIFIC' => 'AP',
) }

