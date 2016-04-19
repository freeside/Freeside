package FS::cust_location::API;

use strict;

# this gets used by FS::cust_main::API and FS::cust_pkg::API,
# so don't use FS::cust_main or FS::cust_pkg here

# some of these could probably be included, but in general,
# probably a bad idea to expose everything in 
# cust_main::Location::location_fields by default
#
#locationname
#district
#latitude
#longitude
#censustract
#censusyear
#geocode
#coord_auto
#addr_clean

sub API_editable_fields {
  return qw(
    address1
    address2
    city
    county
    state
    zip
    country
  );
}

1;
