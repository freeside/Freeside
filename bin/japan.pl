#!/usr/bin/perl

use FS::UID qw( adminsuidsetup );
use FS::Record qw( qsearch );
use FS::cust_main_county;

adminsuidsetup shift;

my $country = 'JP';

foreach my $cust_main_county (
  qsearch('cust_main_county', { 'country' => $country } )
) {

  if ( $cust_main_county->state =~ /\[([\w ]+)\]\s*$/ ) {
    $cust_main_county->state($1);
    my $error = $cust_main_county->replace;
    die $error if $error;
  }

}


#use Locale::SubCountry;
#
##my $state = 'Tôkyô [Tokyo]';
#my $state = 'Tottori';
#
#my $lsc = new Locale::SubCountry 'JP';
#
#print $lsc->code($state)."\n";

